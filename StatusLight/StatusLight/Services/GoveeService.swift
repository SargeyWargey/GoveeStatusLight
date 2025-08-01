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
    func testAPIKey() async throws -> Bool
    func testTemporaryAPIKey(_ testKey: String) async throws -> Bool
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
    
    /// Test the API key with a simple request
    func testAPIKey() async throws -> Bool {
        guard let apiKey = apiKey else {
            print("❌ GoveeService: No API key available for testing")
            throw GoveeServiceError.notAuthenticated
        }
        
        return try await testTemporaryAPIKey(apiKey)
    }
    
    /// Test a specific API key without storing it
    func testTemporaryAPIKey(_ testKey: String) async throws -> Bool {
        let trimmedKey = testKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            print("❌ GoveeService: Empty API key provided for testing")
            throw GoveeServiceError.notAuthenticated
        }
        
        print("🧪 GoveeService: Testing API key...")
        
        // Make a simple request to test the API key
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/user/devices")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedKey, forHTTPHeaderField: "Govee-API-Key")
        
        print("🌐 GoveeService: Testing API request to \(request.url?.absoluteString ?? "unknown")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GoveeService: Invalid response type during API test")
            throw GoveeServiceError.invalidResponse
        }
        
        print("📡 GoveeService: Test response status code: \(httpResponse.statusCode)")
        
        // Print the raw response for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        print("📄 GoveeService: Test response: \(responseString)")
        
        switch httpResponse.statusCode {
        case 200:
            print("✅ GoveeService: API key test successful - received 200 OK")
            return true
            
        case 401:
            print("❌ GoveeService: API key test failed - Unauthorized (401)")
            return false
            
        case 403:
            print("❌ GoveeService: API key test failed - Forbidden (403)")
            return false
            
        case 404:
            print("❌ GoveeService: API key test failed - Not Found (404)")
            return false
            
        case 429:
            print("⏰ GoveeService: API key test failed - Rate Limited (429)")
            return false
            
        default:
            print("❌ GoveeService: API key test failed - Unexpected status code: \(httpResponse.statusCode)")
            return false
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
            print("❌ GoveeService: No API key available")
            throw GoveeServiceError.notAuthenticated
        }
        
        print("🔄 GoveeService: Starting device discovery with API key: \(String(apiKey.prefix(8)))...")
        
        // Validate API key format
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ GoveeService: API key is empty")
            throw GoveeServiceError.invalidAPIKey
        }
        
        if apiKey.count < 10 {
            print("❌ GoveeService: API key appears to be too short")
            throw GoveeServiceError.invalidAPIKey
        }
        
        await rateLimiter.waitIfNeeded()
        
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/user/devices")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        
        print("🌐 GoveeService: Making API request to \(request.url?.absoluteString ?? "unknown")")
        print("🔑 GoveeService: Using API key header: Govee-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GoveeService: Invalid response type")
            throw GoveeServiceError.invalidResponse
        }
        
        print("📡 GoveeService: Received response with status code: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            print("✅ GoveeService: Success response, parsing devices...")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: Response data: \(responseString)")
            
            do {
                // Try to decode with different possible response structures
                if let deviceResponse = try? JSONDecoder().decode(GoveeDeviceResponse.self, from: data) {
                    // Standard Govee API response structure with code, message, and data
                    let discoveredDevices = deviceResponse.data
                    print("🔍 GoveeService: Found \(discoveredDevices.count) devices (standard structure)")
                    
                    for device in discoveredDevices {
                        print("  - Device: \(device.deviceName) (\(device.sku)) - ID: \(device.id)")
                    }
                    
                    let updatedDevices = discoveredDevices.map { device in
                        var updatedDevice = device
                        updatedDevice.isConnected = true
                        updatedDevice.lastUpdated = Date()
                        return updatedDevice
                    }
                    
                    devicesSubject.send(updatedDevices)
                    print("✅ GoveeService: Device discovery completed, \(updatedDevices.count) devices available")
                    
                } else if let directDeviceResponse = try? JSONDecoder().decode(GoveeDirectDeviceResponse.self, from: data) {
                    // Alternative structure with nested data field
                    let discoveredDevices = directDeviceResponse.data
                    print("🔍 GoveeService: Found \(discoveredDevices.count) devices (nested data structure)")
                    
                    for device in discoveredDevices {
                        print("  - Device: \(device.deviceName) (\(device.sku)) - ID: \(device.id)")
                    }
                    
                    let updatedDevices = discoveredDevices.map { device in
                        var updatedDevice = device
                        updatedDevice.isConnected = true
                        updatedDevice.lastUpdated = Date()
                        return updatedDevice
                    }
                    
                    devicesSubject.send(updatedDevices)
                    print("✅ GoveeService: Device discovery completed, \(updatedDevices.count) devices available")
                    
                } else if let simpleResponse = try? JSONDecoder().decode(GoveeSimpleResponse.self, from: data) {
                    // Simple structure with direct devices array
                    let discoveredDevices = simpleResponse.devices
                    print("🔍 GoveeService: Found \(discoveredDevices.count) devices (simple structure)")
                    
                    for device in discoveredDevices {
                        print("  - Device: \(device.deviceName) (\(device.sku)) - ID: \(device.id)")
                    }
                    
                    let updatedDevices = discoveredDevices.map { device in
                        var updatedDevice = device
                        updatedDevice.isConnected = true
                        updatedDevice.lastUpdated = Date()
                        return updatedDevice
                    }
                    
                    devicesSubject.send(updatedDevices)
                    print("✅ GoveeService: Device discovery completed, \(updatedDevices.count) devices available")
                    
                } else if let devices = try? JSONDecoder().decode([GoveeDevice].self, from: data) {
                    // Direct array of devices
                    print("🔍 GoveeService: Found \(devices.count) devices (direct array)")
                    
                    for device in devices {
                        print("  - Device: \(device.deviceName) (\(device.sku)) - ID: \(device.id)")
                    }
                    
                    let updatedDevices = devices.map { device in
                        var updatedDevice = device
                        updatedDevice.isConnected = true
                        updatedDevice.lastUpdated = Date()
                        return updatedDevice
                    }
                    
                    devicesSubject.send(updatedDevices)
                    print("✅ GoveeService: Device discovery completed, \(updatedDevices.count) devices available")
                    
                } else {
                    print("❌ GoveeService: Unable to decode response with any known structure")
                    
                    // Try to parse as generic JSON to understand the structure
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        print("📄 GoveeService: Raw JSON structure: \(json)")
                    }
                    
                    // Print the raw response for debugging
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("📄 GoveeService: Full response: \(responseString)")
                    
                    throw GoveeServiceError.invalidResponse
                }
                
            } catch {
                print("❌ GoveeService: Failed to decode response: \(error)")
                throw GoveeServiceError.invalidResponse
            }
            
        case 401:
            print("❌ GoveeService: Unauthorized (401) - Invalid API key")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: 401 Error response: \(responseString)")
            throw GoveeServiceError.authenticationFailed
            
        case 403:
            print("❌ GoveeService: Forbidden (403) - API key may be invalid or expired")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: 403 Error response: \(responseString)")
            throw GoveeServiceError.authenticationFailed
            
        case 404:
            print("❌ GoveeService: Not Found (404) - API endpoint may be incorrect")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: 404 Error response: \(responseString)")
            throw GoveeServiceError.deviceNotFound
            
        case 429:
            print("⏰ GoveeService: Rate limited (429)")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: 429 Error response: \(responseString)")
            throw GoveeServiceError.rateLimitExceeded
            
        case 500...599:
            print("❌ GoveeService: Server error (\(httpResponse.statusCode))")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: Server error response: \(responseString)")
            throw GoveeServiceError.networkError
            
        default:
            print("❌ GoveeService: Unexpected status code: \(httpResponse.statusCode)")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📄 GoveeService: Error response: \(responseString)")
            throw GoveeServiceError.invalidResponse
        }
    }
    
    func controlDevice(_ device: GoveeDevice, color: GoveeColorValue) async throws {
        print("🎨 GoveeService: Controlling device \(device.deviceName) - setting color RGB(\(color.r),\(color.g),\(color.b)) -> Integer \(color.rgbInteger)")
        try await sendControlCommand(
            device: device,
            capability: GoveeCapability(
                type: "devices.capabilities.color_setting",
                instance: "colorRgb",
                value: .color(color)
            )
        )
        print("✅ GoveeService: Successfully sent color command to \(device.deviceName)")
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
            print("❌ GoveeService: No API key available for device control")
            throw GoveeServiceError.notAuthenticated
        }
        
        print("⏳ GoveeService: Waiting for rate limiter...")
        await rateLimiter.waitIfNeeded()
        
        let controlRequest = GoveeControlRequest(
            requestId: UUID().uuidString,
            payload: GoveeControlPayload(
                sku: device.sku,
                device: device.id,
                capability: capability
            )
        )
        
        print("📤 GoveeService: Sending control command to \(device.deviceName) (SKU: \(device.sku), ID: \(device.id))")
        print("📤 GoveeService: Capability: \(capability.type) - \(capability.instance)")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/router/api/v1/device/control")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")
        request.httpBody = try JSONEncoder().encode(controlRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ GoveeService: Invalid response type")
            throw GoveeServiceError.invalidResponse
        }
        
        print("📡 GoveeService: Received response with status code: \(httpResponse.statusCode)")
        
        // Print response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 GoveeService: Response body: \(responseString)")
        }
        
        switch httpResponse.statusCode {
        case 200:
            print("✅ GoveeService: Successfully controlled device \(device.deviceName)")
            // Success - update device status locally
            updateDeviceStatus(device.id, isConnected: true)
            
        case 429:
            print("⏰ GoveeService: Rate limit exceeded")
            throw GoveeServiceError.rateLimitExceeded
            
        case 404:
            print("❌ GoveeService: Device not found")
            throw GoveeServiceError.deviceNotFound
            
        default:
            print("❌ GoveeService: Control failed with status: \(httpResponse.statusCode)")
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

// Actual Govee API response structure based on the test
private struct GoveeDeviceResponse: Codable {
    let code: Int
    let message: String
    let data: [GoveeDevice]
}

// Alternative response structure that might be used
private struct GoveeDirectDeviceResponse: Codable {
    let data: [GoveeDevice]
}

// Simple response structure
private struct GoveeSimpleResponse: Codable {
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