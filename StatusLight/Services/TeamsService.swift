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
        
        print("🚀 TeamsService: Starting 15-second monitoring cycle")
        
        // Get initial status and then start the restart cycle
        Task {
            do {
                try await refreshStatus()
                print("✅ TeamsService: Initial status fetch completed")
                await startRestartCycle()
            } catch {
                print("❌ TeamsService: Initial status fetch failed: \(error.localizedDescription)")
                await startRestartCycle() // Still start the cycle even if initial fetch fails
            }
        }
    }
    
    private func startRestartCycle() async {
        print("🔄 TeamsService: Starting 15-second restart cycle")
        
        // Create a timer that restarts the entire monitoring process every 15 seconds
        await MainActor.run {
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] timer in
                print("🔄 TeamsService: 15-second restart cycle triggered (valid: \(timer.isValid))")
                print("🚀 TeamsService: Restarting Teams monitoring cycle...")
                
                Task { [weak self] in
                    do {
                        // Stop current monitoring (but don't invalidate the restart timer)
                        await MainActor.run {
                            // Don't call stopMonitoring() here as it would stop this timer
                            print("🔄 TeamsService: Refreshing Teams status...")
                        }
                        
                        // Fetch fresh status
                        try await self?.refreshStatus()
                        print("✅ TeamsService: Restart cycle status fetch completed")
                        
                    } catch {
                        print("❌ TeamsService: Restart cycle failed: \(error.localizedDescription)")
                    }
                }
            }
            
            // Ensure timer runs on main run loop with common modes to prevent pausing
            RunLoop.main.add(monitoringTimer!, forMode: .common)
            print("✅ TeamsService: 15-second restart cycle timer started")
        }
    }
    
    func stopMonitoring() {
        if monitoringTimer != nil {
            print("🛑 TeamsService: Stopping 15-second polling timer")
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            print("✅ TeamsService: Timer stopped successfully")
        } else {
            print("ℹ️ TeamsService: No timer to stop")
        }
    }
    
    private func setupAuthentication() {
        // Check if we have stored tokens and start monitoring if authenticated
        microsoftGraphService.isAuthenticated
            .sink { [weak self] isAuthenticated in
                print("🔑 TeamsService: Authentication status changed to: \(isAuthenticated)")
                if isAuthenticated {
                    print("🚀 TeamsService: User is authenticated, starting 15-second monitoring...")
                    self?.startMonitoring()
                } else {
                    print("🛑 TeamsService: User not authenticated, stopping monitoring")
                    self?.stopMonitoring()
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