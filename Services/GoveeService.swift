//
//  GoveeService.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import Combine

protocol GoveeServiceProtocol {
    var devices: AnyPublisher<[GoveeDevice], Never> { get }
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> { get }
    var isConfigured: AnyPublisher<Bool, Never> { get }
    
    func configureAPIKey(_ apiKey: String) async throws
    func loadStoredAPIKey() async
    func removeAPIKey() async throws
    func validateAPIKey() async throws -> Bool
    func discoverDevices() async throws
    func controlDevice(_ device: GoveeDevice, color: GoveeColorValue) async throws
    func controlDevice(_ device: GoveeDevice, brightness: Int) async throws
    func controlDevice(_ device: GoveeDevice, power: Bool) async throws
}

class GoveeService: GoveeServiceProtocol, ObservableObject {
    private let devicesSubject = CurrentValueSubject<[GoveeDevice], Never>([])
    private let connectionSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let configuredSubject = CurrentValueSubject<Bool, Never>(false)
    
    private var apiKey: String?
    private var rateLimiter: RateLimiter
    private var cancellables = Set<AnyCancellable>()
    
    private let baseURL = "https://openapi.api.govee.com"
    
    var devices: AnyPublisher<[GoveeDevice], Never> {
        devicesSubject.eraseToAnyPublisher()
    }
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        connectionSubject.eraseToAnyPublisher()
    }
    
    var isConfigured: AnyPublisher<Bool, Never> {
        configuredSubject.eraseToAnyPublisher()
    }
    
    init() {
        // Initialize rate limiter with Govee's limits: 10 requests per minute
        self.rateLimiter = RateLimiter(maxRequests: 10, timeWindow: 60)
        
        // Load stored API key on initialization
        Task {
            await loadStoredAPIKey()
        }
    }
    
    // MARK: - API Key Management
    
    /// Configure and store a new API key securely
    func configureAPIKey(_ apiKey: String) async throws {
        connectionSubject.send(.connecting)
        
        // Validate the API key format (basic validation)
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionSubject.send(.error("API key cannot be empty"))
            throw GoveeServiceError.invalidAPIKey
        }
        
        // Store temporarily for validation
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = trimmedAPIKey
        
        // Validate the API key by testing it
        do {
            let isValid = try await validateAPIKey()
            if isValid {
                // Store securely in keychain
                try KeychainService.store(trimmedAPIKey, forAccount: KeychainService.Accounts.goveeAPIKey)
                configuredSubject.send(true)
                connectionSubject.send(.connected)
            } else {
                self.apiKey = nil
                connectionSubject.send(.error("Invalid API key - please check your key and try again"))
                throw GoveeServiceError.authenticationFailed
            }
        } catch {
            self.apiKey = nil
            configuredSubject.send(false)
            connectionSubject.send(.error("Failed to validate API key: \(error.localizedDescription)"))
            throw error
        }
    }
    
    /// Load stored API key from keychain
    func loadStoredAPIKey() async {
        do {
            if let storedKey = try KeychainService.retrieve(forAccount: KeychainService.Accounts.goveeAPIKey) {
                self.apiKey = storedKey
                configuredSubject.send(true)
                connectionSubject.send(.connected)
                
                // Optionally validate the stored key
                try await validateStoredKey()
            } else {
                configuredSubject.send(false)
                connectionSubject.send(.disconnected)
            }
        } catch {
            print("Failed to load stored API key: \(error.localizedDescription)")
            configuredSubject.send(false)
            connectionSubject.send(.disconnected)
        }
    }
    
    /// Remove stored API key
    func removeAPIKey() async throws {
        try KeychainService.delete(forAccount: KeychainService.Accounts.goveeAPIKey)
        self.apiKey = nil
        configuredSubject.send(false)
        connectionSubject.send(.disconnected)
        devicesSubject.send([])
    }
    
    /// Validate the current API key by making a test request
    func validateAPIKey() async throws -> Bool {
        guard let apiKey = apiKey else {
            throw GoveeServiceError.notAuthenticated
        }
        
        await rateLimiter.waitIfNeeded()
        
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/user/devices")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // Consider 200 (success) and 404 (no devices) as valid API key responses
            // 401/403 would indicate invalid API key
            switch httpResponse.statusCode {
            case 200, 404:
                return true
            case 401, 403:
                return false
            case 429:
                // Rate limited, but API key is likely valid
                return true
            default:
                return false
            }
        } catch {
            // Network errors don't necessarily mean invalid API key
            throw GoveeServiceError.networkError
        }
    }
    
    /// Validate stored key periodically
    private func validateStoredKey() async throws {
        do {
            let isValid = try await validateAPIKey()
            if !isValid {
                // API key is no longer valid, remove it
                try await removeAPIKey()
                connectionSubject.send(.error("Stored API key is no longer valid"))
            }
        } catch {
            // Don't remove key for network errors, just log
            print("Could not validate stored API key: \(error.localizedDescription)")
        }
    }
    
    func discoverDevices() async throws {
        guard let apiKey = apiKey else {
            throw GoveeServiceError.notAuthenticated
        }
        
        await rateLimiter.waitIfNeeded()
        
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/user/devices")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoveeServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let deviceResponse = try JSONDecoder().decode(GoveeDeviceResponse.self, from: data)
            let updatedDevices = deviceResponse.payload.devices.map { device in
                var updatedDevice = device
                updatedDevice.isConnected = true
                updatedDevice.lastUpdated = Date()
                return updatedDevice
            }
            devicesSubject.send(updatedDevices)
            
        case 429:
            throw GoveeServiceError.rateLimitExceeded
            
        default:
            throw GoveeServiceError.invalidResponse
        }
    }
    
    func controlDevice(_ device: GoveeDevice, color: GoveeColorValue) async throws {
        try await sendControlCommand(
            device: device,
            capability: GoveeCapability(
                type: "devices.capabilities.color_setting",
                instance: "colorRgb",
                value: .color(color)
            )
        )
    }
    
    func controlDevice(_ device: GoveeDevice, brightness: Int) async throws {
        let clampedBrightness = max(1, min(100, brightness))
        try await sendControlCommand(
            device: device,
            capability: GoveeCapability(
                type: "devices.capabilities.range",
                instance: "brightness",
                value: .integer(clampedBrightness)
            )
        )
    }
    
    func controlDevice(_ device: GoveeDevice, power: Bool) async throws {
        try await sendControlCommand(
            device: device,
            capability: GoveeCapability(
                type: "devices.capabilities.on_off",
                instance: "powerSwitch",
                value: .integer(power ? 1 : 0)
            )
        )
    }
    
    private func sendControlCommand(device: GoveeDevice, capability: GoveeCapability) async throws {
        guard let apiKey = apiKey else {
            throw GoveeServiceError.notAuthenticated
        }
        
        await rateLimiter.waitIfNeeded()
        
        let controlRequest = GoveeControlRequest(
            requestId: UUID().uuidString,
            payload: GoveeControlPayload(
                sku: device.sku,
                device: device.id,
                capability: capability
            )
        )
        
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/device/control")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        request.httpBody = try JSONEncoder().encode(controlRequest)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoveeServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            // Success - update device status locally
            updateDeviceStatus(device.id, isConnected: true)
            
        case 429:
            throw GoveeServiceError.rateLimitExceeded
            
        case 404:
            throw GoveeServiceError.deviceNotFound
            
        default:
            throw GoveeServiceError.controlFailed
        }
    }
    
    private func updateDeviceStatus(_ deviceId: String, isConnected: Bool) {
        var currentDevices = devicesSubject.value
        if let index = currentDevices.firstIndex(where: { $0.id == deviceId }) {
            currentDevices[index].isConnected = isConnected
            currentDevices[index].lastUpdated = Date()
            devicesSubject.send(currentDevices)
        }
    }
}

// MARK: - Supporting Types

private struct GoveeDeviceResponse: Codable {
    let payload: GoveeDevicePayload
}

private struct GoveeDevicePayload: Codable {
    let devices: [GoveeDevice]
}

enum GoveeServiceError: LocalizedError {
    case notAuthenticated
    case invalidAPIKey
    case authenticationFailed
    case rateLimitExceeded
    case deviceNotFound
    case controlFailed
    case invalidResponse
    case networkError
    case keychainError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Govee API key not provided"
        case .invalidAPIKey:
            return "Invalid API key format"
        case .authenticationFailed:
            return "Failed to authenticate with Govee API - please check your API key"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again in a minute."
        case .deviceNotFound:
            return "Device not found or not accessible"
        case .controlFailed:
            return "Failed to control device"
        case .invalidResponse:
            return "Invalid response from Govee API"
        case .networkError:
            return "Network connection error"
        case .keychainError:
            return "Failed to access secure storage"
        }
    }
}

// MARK: - Rate Limiter

class RateLimiter: @unchecked Sendable {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "rate-limiter", attributes: .concurrent)
    
    init(maxRequests: Int, timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func waitIfNeeded() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                let now = Date()
                
                // Remove old requests outside the time window
                self.requestTimes = self.requestTimes.filter { now.timeIntervalSince($0) < self.timeWindow }
                
                if self.requestTimes.count >= self.maxRequests {
                    // Calculate how long to wait
                    let oldestRequest = self.requestTimes.first!
                    let waitTime = self.timeWindow - now.timeIntervalSince(oldestRequest)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                        self.requestTimes.append(now.addingTimeInterval(waitTime))
                        continuation.resume()
                    }
                } else {
                    self.requestTimes.append(now)
                    continuation.resume()
                }
            }
        }
    }
}