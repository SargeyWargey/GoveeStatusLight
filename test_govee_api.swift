#!/usr/bin/env swift

import Foundation

// Govee API Test Script
// Usage: swift test_govee_api.swift YOUR_API_KEY_HERE

guard CommandLine.arguments.count > 1 else {
    print("❌ Usage: swift test_govee_api.swift YOUR_API_KEY_HERE")
    print("Example: swift test_govee_api.swift abc123-def456-ghi789")
    exit(1)
}

let apiKey = CommandLine.arguments[1]
let baseURL = "https://openapi.api.govee.com"
let endpoint = "\(baseURL)/router/api/v1/user/devices"

print("🧪 Testing Govee API Key...")
print("🔑 API Key: \(String(apiKey.prefix(8)))...")
print("🌐 Endpoint: \(endpoint)")
print("")

// Create the request
var request = URLRequest(url: URL(string: endpoint)!)
request.httpMethod = "GET"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(apiKey, forHTTPHeaderField: "Govee-API-Key")

// Make the request
let semaphore = DispatchSemaphore(value: 0)
var responseData: Data?
var response: URLResponse?
var error: Error?

URLSession.shared.dataTask(with: request) { data, urlResponse, err in
    responseData = data
    response = urlResponse
    error = err
    semaphore.signal()
}.resume()

semaphore.wait()

// Handle errors
if let error = error {
    print("❌ Network Error: \(error.localizedDescription)")
    exit(1)
}

guard let httpResponse = response as? HTTPURLResponse else {
    print("❌ Invalid response type")
    exit(1)
}

print("📡 Status Code: \(httpResponse.statusCode)")

// Print response headers
print("📋 Response Headers:")
for (key, value) in httpResponse.allHeaderFields {
    print("  \(key): \(value)")
}

print("")

// Handle response
if let data = responseData {
    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
    print("📄 Response Body:")
    print(responseString)
    print("")
    
    switch httpResponse.statusCode {
    case 200:
        print("✅ SUCCESS: API key is valid!")
        print("📊 Response length: \(data.count) bytes")
        
        // Try to parse as JSON
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            print("✅ JSON parsing successful")
            if let jsonDict = json as? [String: Any] {
                print("📋 JSON structure:")
                for (key, value) in jsonDict {
                    print("  \(key): \(value)")
                }
            }
        } else {
            print("❌ JSON parsing failed")
        }
        
    case 401:
        print("❌ ERROR: Unauthorized - Invalid API key")
        print("💡 Make sure your API key is correct and hasn't expired")
        
    case 403:
        print("❌ ERROR: Forbidden - API key may be invalid or expired")
        print("💡 Check if your API key is still valid")
        
    case 404:
        print("❌ ERROR: Not Found - API endpoint may be incorrect")
        print("💡 This might indicate an API version issue")
        
    case 429:
        print("⏰ WARNING: Rate Limited - Too many requests")
        print("💡 Wait a minute and try again")
        
    case 500...599:
        print("❌ ERROR: Server Error (\(httpResponse.statusCode))")
        print("💡 Govee servers may be experiencing issues")
        
    default:
        print("❌ ERROR: Unexpected status code \(httpResponse.statusCode)")
        print("💡 Unknown error occurred")
    }
} else {
    print("❌ No response data received")
}

print("")
print("🔍 Test completed!") 