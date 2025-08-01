//
//  MicrosoftGraphService.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import Combine
import AuthenticationServices

// MARK: - Microsoft Graph Configuration
struct MicrosoftGraphConfig {
    static let clientId = "5d8ef8c6-cae4-43e8-bf39-a8001529fe51" // Your Azure app client ID
    static let redirectURI = "msauth.com.sargey.goveeteamssync://auth"
    static let scopes = [
        "https://graph.microsoft.com/Presence.Read",
        "https://graph.microsoft.com/Calendars.Read",
        "https://graph.microsoft.com/User.Read"
    ]
    static let authority = "https://login.microsoftonline.com/common"
}

// MARK: - Microsoft Graph Models
struct GraphPresenceResponse: Codable {
    let availability: String
    let activity: String
    let statusMessage: GraphStatusMessage?
    
    var teamsPresence: TeamsPresence {
        switch availability.lowercased() {
        case "available":
            return .available
        case "away", "offline":
            return .away
        case "busy":
            return activity.lowercased().contains("call") ? .inACall : 
                   activity.lowercased().contains("meeting") ? .inAMeeting : .busy
        case "donotdisturb":
            return .doNotDisturb
        default:
            return .unknown
        }
    }
}

struct GraphStatusMessage: Codable {
    let message: GraphMessage?
    let publishedDateTime: String?
}

struct GraphMessage: Codable {
    let content: String?
    let contentType: String?
}

struct GraphCalendarResponse: Codable {
    let value: [GraphEvent]
}

struct GraphEvent: Codable {
    let id: String
    let subject: String
    let start: GraphDateTime
    let end: GraphDateTime
    let isAllDay: Bool
    let showAs: String
    let recurrence: GraphRecurrence?
    let attendees: [GraphAttendee]
    let location: GraphLocation?
    let webLink: String?
    
    func toCalendarEvent() -> CalendarEvent {
        let startDate = ISO8601DateFormatter().date(from: start.dateTime) ?? Date()
        let endDate = ISO8601DateFormatter().date(from: end.dateTime) ?? Date()
        
        return CalendarEvent(
            id: id,
            subject: subject,
            startTime: startDate,
            endTime: endDate,
            isAllDay: isAllDay,
            showAs: BusyStatus(rawValue: showAs.lowercased()) ?? .unknown,
            isRecurring: recurrence != nil,
            meetingType: MeetingType(
                duration: endDate.timeIntervalSince(startDate),
                isAllDay: isAllDay
            ),
            attendees: attendees.map { attendee in
                Attendee(
                    name: attendee.emailAddress?.name,
                    email: attendee.emailAddress?.address ?? "",
                    responseStatus: ResponseStatus(rawValue: attendee.status?.response ?? "none") ?? .none
                )
            },
            location: location?.displayName,
            webLink: webLink
        )
    }
}

struct GraphDateTime: Codable {
    let dateTime: String
    let timeZone: String
}

struct GraphRecurrence: Codable {
    let pattern: GraphRecurrencePattern
}

struct GraphRecurrencePattern: Codable {
    let type: String
    let interval: Int
}

struct GraphAttendee: Codable {
    let emailAddress: GraphEmailAddress?
    let status: GraphResponseStatus?
}

struct GraphEmailAddress: Codable {
    let name: String?
    let address: String
}

struct GraphResponseStatus: Codable {
    let response: String
    let time: String?
}

struct GraphLocation: Codable {
    let displayName: String?
}

// MARK: - Microsoft Graph Service
class MicrosoftGraphService: NSObject, ObservableObject, @unchecked Sendable {
    private let baseURL = "https://graph.microsoft.com/v1.0"
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpirationDate: Date?
    
    private let statusSubject = CurrentValueSubject<TeamsStatusInfo?, Never>(nil)
    private let authenticationSubject = CurrentValueSubject<Bool, Never>(false)
    private let connectionSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let eventsSubject = CurrentValueSubject<[CalendarEvent], Never>([])
    
    private var cancellables = Set<AnyCancellable>()
    
    var currentStatus: AnyPublisher<TeamsStatusInfo?, Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        authenticationSubject.eraseToAnyPublisher()
    }
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        connectionSubject.eraseToAnyPublisher()
    }
    
    var upcomingEvents: AnyPublisher<[CalendarEvent], Never> {
        eventsSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        loadStoredTokens()
    }
    
    // MARK: - Authentication
    func authenticate() async throws {
        connectionSubject.send(.connecting)
        
        guard !MicrosoftGraphConfig.clientId.isEmpty && MicrosoftGraphConfig.clientId != "YOUR_ACTUAL_CLIENT_ID_HERE" else {
            connectionSubject.send(.error("Client ID not configured. Please set up Azure app registration."))
            throw MicrosoftGraphError.configurationError
        }
        
        try await performOAuthFlow()
    }
    
    func signOut() async throws {
        // Clear tokens from memory
        self.accessToken = nil
        self.refreshToken = nil
        self.tokenExpirationDate = nil
        
        // Clear tokens from keychain
        try KeychainService.delete(forAccount: KeychainService.Accounts.microsoftAccessToken)
        try KeychainService.delete(forAccount: KeychainService.Accounts.microsoftRefreshToken)
        try KeychainService.delete(forAccount: KeychainService.Accounts.microsoftTokenExpiration)
        
        // Update subjects
        authenticationSubject.send(false)
        connectionSubject.send(.disconnected)
        statusSubject.send(nil)
    }
    
    private func performOAuthFlow() async throws {
        let authURL = buildAuthURL()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "msauth.com.sargey.goveeteamssync"
                ) { [weak self] callbackURL, error in
                    if let error = error {
                        self?.connectionSubject.send(.error("Authentication failed: \(error.localizedDescription)"))
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        let error = MicrosoftGraphError.authenticationFailed
                        self?.connectionSubject.send(.error("No callback URL received"))
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    Task { @MainActor in
                        do {
                            try await self?.handleAuthCallback(callbackURL)
                            continuation.resume()
                        } catch {
                            self?.connectionSubject.send(.error("Token exchange failed: \(error.localizedDescription)"))
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
        }
    }
    
    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "\(MicrosoftGraphConfig.authority)/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: MicrosoftGraphConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: MicrosoftGraphConfig.redirectURI),
            URLQueryItem(name: "scope", value: MicrosoftGraphConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        return components.url!
    }
    
    private func handleAuthCallback(_ url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw MicrosoftGraphError.authenticationFailed
        }
        
        try await exchangeCodeForTokens(code)
    }
    
    private func exchangeCodeForTokens(_ code: String) async throws {
        let tokenURL = URL(string: "\(MicrosoftGraphConfig.authority)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": MicrosoftGraphConfig.clientId,
            "code": code,
            "redirect_uri": MicrosoftGraphConfig.redirectURI,
            "grant_type": "authorization_code",
            "scope": MicrosoftGraphConfig.scopes.joined(separator: " ")
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
         .joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MicrosoftGraphError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        try storeTokensSecurely()
        
        authenticationSubject.send(true)
        connectionSubject.send(.connected)
    }
    
    // MARK: - Token Management
    private func storeTokensSecurely() throws {
        guard let accessToken = accessToken else { return }
        
        do {
            try KeychainService.store(accessToken, forAccount: KeychainService.Accounts.microsoftAccessToken)
            
            if let refreshToken = refreshToken {
                try KeychainService.store(refreshToken, forAccount: KeychainService.Accounts.microsoftRefreshToken)
            }
            
            // Store token expiration date
            if let expirationDate = tokenExpirationDate {
                let expirationString = ISO8601DateFormatter().string(from: expirationDate)
                try KeychainService.store(expirationString, forAccount: KeychainService.Accounts.microsoftTokenExpiration)
            }
        } catch {
            throw MicrosoftGraphError.keychainError
        }
    }
    
    private func loadStoredTokens() {
        do {
            if let accessToken = try KeychainService.retrieve(forAccount: KeychainService.Accounts.microsoftAccessToken) {
                self.accessToken = accessToken
                
                // Load refresh token
                if let refreshToken = try KeychainService.retrieve(forAccount: KeychainService.Accounts.microsoftRefreshToken) {
                    self.refreshToken = refreshToken
                }
                
                // Load token expiration date
                if let expirationString = try KeychainService.retrieve(forAccount: KeychainService.Accounts.microsoftTokenExpiration),
                   let expirationDate = ISO8601DateFormatter().date(from: expirationString) {
                    self.tokenExpirationDate = expirationDate
                }
                
                // Check if token is still valid
                if isTokenValid() {
                    authenticationSubject.send(true)
                    connectionSubject.send(.connected)
                    print("📱 MicrosoftGraphService: Loaded valid stored tokens successfully")
                } else {
                    print("📱 MicrosoftGraphService: Stored tokens expired, will refresh on next API call")
                    authenticationSubject.send(true) // Still authenticated, just needs refresh
                    connectionSubject.send(.connected)
                }
            } else {
                // No stored tokens, start with mock data for debugging
                print("📱 MicrosoftGraphService: No stored tokens found, starting mock data for debugging")
                startMockDataGeneration()
            }
        } catch {
            print("❌ MicrosoftGraphService: Failed to load stored tokens: \(error.localizedDescription)")
            startMockDataGeneration()
        }
    }
    
    // MARK: - API Calls
    func refreshPresence() async throws {
        print("🔄 MicrosoftGraphService: Starting Teams status polling attempt...")
        print("📊 MicrosoftGraphService: Checking token validity...")
        
        if !isTokenValid() {
            print("🔄 MicrosoftGraphService: Token expired, refreshing...")
            try await refreshTokenIfNeeded()
            print("✅ MicrosoftGraphService: Token refreshed successfully")
        } else {
            print("✅ MicrosoftGraphService: Token is valid, proceeding with API call")
        }
        
        guard let accessToken = accessToken else {
            print("❌ MicrosoftGraphService: No access token available")
            throw MicrosoftGraphError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/me/presence")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("📡 MicrosoftGraphService: Sending GET request to \(url.absoluteString)")
        let startTime = Date()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let requestDuration = Date().timeIntervalSince(startTime)
        print("⏱️ MicrosoftGraphService: API request completed in \(String(format: "%.2f", requestDuration))s")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ MicrosoftGraphService: Invalid HTTP response received")
            throw MicrosoftGraphError.invalidResponse
        }
        
        print("📨 MicrosoftGraphService: Received HTTP \(httpResponse.statusCode) response")
        
        switch httpResponse.statusCode {
        case 200:
            do {
                let presenceResponse = try JSONDecoder().decode(GraphPresenceResponse.self, from: data)
                let statusInfo = TeamsStatusInfo(
                    presence: presenceResponse.teamsPresence,
                    activity: presenceResponse.activity,
                    lastActiveTime: Date(),
                    statusMessage: presenceResponse.statusMessage?.message?.content
                )
                
                print("✅ MicrosoftGraphService: Successfully parsed Teams presence data")
                print("👤 MicrosoftGraphService: Teams status - \(presenceResponse.teamsPresence.displayName) (\(presenceResponse.activity))")
                if let statusMessage = statusInfo.statusMessage {
                    print("💬 MicrosoftGraphService: Status message: \(statusMessage)")
                }
                
                statusSubject.send(statusInfo)
                print("✅ MicrosoftGraphService: Teams status updated successfully - \(presenceResponse.teamsPresence.displayName) (\(presenceResponse.activity))")
                
            } catch {
                print("❌ MicrosoftGraphService: Failed to decode presence response: \(error.localizedDescription)")
                throw MicrosoftGraphError.invalidResponse
            }
            
        case 401:
            print("🔐 MicrosoftGraphService: Authentication expired (401), attempting token refresh...")
            try await refreshTokenIfNeeded()
            print("❌ MicrosoftGraphService: Authentication expired, client needs to retry")
            throw MicrosoftGraphError.authenticationExpired
            
        case 429:
            print("⚠️ MicrosoftGraphService: Rate limit exceeded (429) - backing off")
            throw MicrosoftGraphError.rateLimitExceeded
            
        default:
            print("❌ MicrosoftGraphService: Unexpected HTTP status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 MicrosoftGraphService: Response body: \(responseString)")
            }
            throw MicrosoftGraphError.invalidResponse
        }
    }
    
    func refreshCalendarEvents() async throws {
        if !isTokenValid() {
            try await refreshTokenIfNeeded()
        }
        
        guard let accessToken = accessToken else {
            throw MicrosoftGraphError.notAuthenticated
        }
        
        let startTime = ISO8601DateFormatter().string(from: Date())
        let endTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 60 * 60)) // Next 24 hours
        
        let url = URL(string: "\(baseURL)/me/calendar/calendarView?startDateTime=\(startTime)&endDateTime=\(endTime)&$orderby=start/dateTime")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MicrosoftGraphError.invalidResponse
        }
        
        let calendarResponse = try JSONDecoder().decode(GraphCalendarResponse.self, from: data)
        let events = calendarResponse.value.map { $0.toCalendarEvent() }
        eventsSubject.send(events)
    }
    
    private func isTokenValid() -> Bool {
        guard let expirationDate = tokenExpirationDate else { return false }
        return Date() < expirationDate.addingTimeInterval(-300) // 5 minutes buffer
    }
    
    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = refreshToken else {
            throw MicrosoftGraphError.authenticationExpired
        }
        
        let tokenURL = URL(string: "\(MicrosoftGraphConfig.authority)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "client_id": MicrosoftGraphConfig.clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "scope": MicrosoftGraphConfig.scopes.joined(separator: " ")
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
         .joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // If refresh fails, clear stored tokens and require re-authentication
            self.accessToken = nil
            self.refreshToken = nil
            self.tokenExpirationDate = nil
            try? KeychainService.delete(forAccount: KeychainService.Accounts.microsoftAccessToken)
            try? KeychainService.delete(forAccount: KeychainService.Accounts.microsoftRefreshToken)
            try? KeychainService.delete(forAccount: KeychainService.Accounts.microsoftTokenExpiration)
            authenticationSubject.send(false)
            connectionSubject.send(.disconnected)
            throw MicrosoftGraphError.authenticationExpired
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.accessToken
        if let newRefreshToken = tokenResponse.refreshToken {
            self.refreshToken = newRefreshToken
        }
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        try storeTokensSecurely()
    }
    
    
    // MARK: - Mock Data for Debugging
    private func startMockDataGeneration() {
        authenticationSubject.send(false)
        connectionSubject.send(.disconnected)
        
        // Generate mock Teams status for debugging
        generateMockTeamsStatus()
        
        // Update mock status every 30 seconds to simulate real Teams behavior
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.generateMockTeamsStatus()
        }
    }
    
    private func generateMockTeamsStatus() {
        let mockStatuses: [TeamsPresence] = [.available, .busy, .away, .inAMeeting, .inACall, .doNotDisturb]
        let randomStatus = mockStatuses.randomElement() ?? .available
        
        let activities = [
            "Working from home",
            "In focus time",
            "Available for chat",
            "In a Teams meeting",
            "On a phone call",
            "Presenting",
            "Away from desk"
        ]
        
        let mockStatus = TeamsStatusInfo(
            presence: randomStatus,
            activity: activities.randomElement(),
            lastActiveTime: Date(),
            statusMessage: "Mock status for debugging"
        )
        
        print("🧪 MicrosoftGraphService: Generated mock Teams status: \(randomStatus.displayName)")
        statusSubject.send(mockStatus)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension MicrosoftGraphService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSWindow()
    }
}

// MARK: - Supporting Types
private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

enum MicrosoftGraphError: LocalizedError {
    case configurationError
    case authenticationFailed
    case tokenExchangeFailed
    case keychainError
    case notAuthenticated
    case authenticationExpired
    case rateLimitExceeded
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "Microsoft Graph client ID not configured"
        case .authenticationFailed:
            return "Authentication with Microsoft failed"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .keychainError:
            return "Failed to store tokens securely"
        case .notAuthenticated:
            return "User is not authenticated with Microsoft"
        case .authenticationExpired:
            return "Authentication has expired"
        case .rateLimitExceeded:
            return "Microsoft Graph API rate limit exceeded"
        case .invalidResponse:
            return "Invalid response from Microsoft Graph API"
        }
    }
}
