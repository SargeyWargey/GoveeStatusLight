#!/usr/bin/env swift

import Foundation
import Security

// Script to configure the Govee API key in the macOS Keychain
// This will help test the app with the correct API key

let apiKey = "1ef6c337-e7f5-4a4b-99d5-178d8ca5f7e1"
let serviceIdentifier = "StatusLight"
let account = "govee_api_key"

print("🔧 Configuring Govee API Key in Keychain...")
print("🔑 API Key: \(String(apiKey.prefix(8)))...")
print("")

// Convert API key to data
guard let data = apiKey.data(using: .utf8) else {
    print("❌ Failed to convert API key to data")
    exit(1)
}

// Create keychain query
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

if status == errSecSuccess {
    print("✅ API key successfully stored in Keychain")
    print("📱 You can now run the StatusLight app and it should use this API key")
} else {
    print("❌ Failed to store API key in Keychain: \(status)")
    exit(1)
}

print("")
print("🎯 Next steps:")
print("1. Run the StatusLight app")
print("2. The app should automatically load the API key")
print("3. Try the 'Refresh Devices' button")
print("4. Check the console for detailed logging") 