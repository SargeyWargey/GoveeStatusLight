//
//  TeamsService.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import Combine

protocol TeamsServiceProtocol {
    var currentStatus: AnyPublisher<TeamsStatusInfo?, Never> { get }
    var isAuthenticated: AnyPublisher<Bool, Never> { get }
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> { get }
    
    func authenticate() async throws
    func signOut() async throws
    func refreshStatus() async throws
    func startMonitoring()
    func stopMonitoring()
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

class TeamsService: TeamsServiceProtocol, ObservableObject {
    private let microsoftGraphService = MicrosoftGraphService()
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    
    var currentStatus: AnyPublisher<TeamsStatusInfo?, Never> {
        microsoftGraphService.currentStatus
    }
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        microsoftGraphService.isAuthenticated
    }
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        microsoftGraphService.connectionStatus
    }
    
    init() {
        setupAuthentication()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func authenticate() async throws {
        try await microsoftGraphService.authenticate()
        startMonitoring()
    }
    
    func signOut() async throws {
        stopMonitoring()
        try await microsoftGraphService.signOut()
    }
    
    func refreshStatus() async throws {
        try await microsoftGraphService.refreshPresence()
    }
    
    func startMonitoring() {
        stopMonitoring() // Stop any existing monitoring
        
        // Poll for status updates every 30 seconds to respect Microsoft Graph rate limits
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                try? await self?.refreshStatus()
            }
        }
        
        // Get initial status
        Task {
            try? await refreshStatus()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func setupAuthentication() {
        // Check if we have stored tokens and start monitoring if authenticated
        microsoftGraphService.isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.startMonitoring()
                }
            }
            .store(in: &cancellables)
    }
}

enum TeamsServiceError: LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case networkError
    case rateLimitExceeded
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated with Microsoft Teams"
        case .authenticationFailed:
            return "Failed to authenticate with Microsoft Teams"
        case .networkError:
            return "Network connection error"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .invalidResponse:
            return "Invalid response from Microsoft Teams API"
        }
    }
}