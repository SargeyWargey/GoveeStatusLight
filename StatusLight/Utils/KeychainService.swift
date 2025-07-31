//
//  KeychainService.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/31/25.
//

import Foundation
import Security

/// A utility service for securely storing and retrieving sensitive data using macOS Keychain
class KeychainService {
    
    /// Service identifier for all StatusLight keychain items
    private static let serviceIdentifier = "StatusLight"
    
    /// Store a string value securely in the keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - account: The account identifier (e.g., "govee_api_key", "teams_token")
    /// - Throws: KeychainError if the operation fails
    static func store(_ value: String, forAccount account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status: status)
        }
    }
    
    /// Retrieve a string value from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: KeychainError if the operation fails
    static func retrieve(forAccount account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw KeychainError.retrieveFailed(status: status)
        }
    }
    
    /// Delete a stored value from the keychain
    /// - Parameter account: The account identifier
    /// - Throws: KeychainError if the operation fails
    static func delete(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
    
    /// Check if a value exists in the keychain for the given account
    /// - Parameter account: The account identifier
    /// - Returns: true if the value exists, false otherwise
    static func exists(forAccount account: String) -> Bool {
        do {
            return try retrieve(forAccount: account) != nil
        } catch {
            return false
        }
    }
}

// MARK: - KeychainError

enum KeychainError: LocalizedError {
    case invalidData
    case storeFailed(status: OSStatus)
    case retrieveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format for keychain storage"
        case .storeFailed(let status):
            return "Failed to store item in keychain (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve item from keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete item from keychain (status: \(status))"
        }
    }
}

// MARK: - Keychain Account Constants

extension KeychainService {
    /// Predefined account identifiers for common use cases
    struct Accounts {
        static let goveeAPIKey = "govee_api_key"
        static let microsoftAccessToken = "microsoft_access_token"
        static let microsoftRefreshToken = "microsoft_refresh_token"
    }
}