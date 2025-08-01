//
//  GoveeDevice.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import SwiftUI

struct GoveeDevice: Identifiable, Codable {
    let id: String
    let sku: String
    let deviceName: String
    let deviceType: String?
    let capabilities: [DeviceCapability]
    var isConnected: Bool = false
    var lastUpdated: Date = Date()
    
    enum CodingKeys: String, CodingKey {
        case id = "device"
        case sku
        case deviceName
        case deviceType = "type"
        case capabilities
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle device ID which can be either String or Int
        if let deviceId = try? container.decode(String.self, forKey: .id) {
            self.id = deviceId
        } else if let deviceIdInt = try? container.decode(Int.self, forKey: .id) {
            self.id = String(deviceIdInt)
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "device field must be String or Int"))
        }
        
        self.sku = try container.decode(String.self, forKey: .sku)
        self.deviceName = try container.decode(String.self, forKey: .deviceName)
        self.deviceType = try? container.decode(String.self, forKey: .deviceType) // Make optional for group devices
        self.capabilities = try container.decode([DeviceCapability].self, forKey: .capabilities)
        self.isConnected = false
        self.lastUpdated = Date()
    }
}

struct DeviceCapability: Codable {
    let type: String
    let instance: String
    // parameters field completely removed - not needed for basic device listing
    
    enum CodingKeys: String, CodingKey {
        case type, instance
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(instance, forKey: .instance)
    }
}

// Custom decoder that ignores unknown fields
extension DeviceCapability {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        instance = try container.decode(String.self, forKey: .instance)
        
        // Explicitly ignore any other fields (like parameters) by not decoding them
        // This is the key fix - we only decode the fields we care about
    }
}

// Helper struct to handle Any JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

struct GoveeColorValue: Codable, Equatable {
    let r: Int
    let g: Int
    let b: Int
    
    init(r: Int, g: Int, b: Int) {
        self.r = max(0, min(255, r))
        self.g = max(0, min(255, g))
        self.b = max(0, min(255, b))
    }
    
    init(color: Color) {
        let nsColor = NSColor(color)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        self.init(r: r, g: g, b: b)
    }
    
    var color: Color {
        Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }
    
    /// Convert RGB values to a single integer for Govee API (RGB to 24-bit integer)
    var rgbInteger: Int {
        return (r << 16) | (g << 8) | b
    }
    
    static func == (lhs: GoveeColorValue, rhs: GoveeColorValue) -> Bool {
        return lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b
    }
}

struct GoveeControlRequest: Codable {
    let requestId: String
    let payload: GoveeControlPayload
}

struct GoveeControlPayload: Codable {
    let sku: String
    let device: String
    let capability: GoveeCapability
}

struct GoveeCapability: Codable {
    let type: String
    let instance: String
    let value: GoveeCapabilityValue
}

enum GoveeCapabilityValue: Codable {
    case integer(Int)
    case color(GoveeColorValue)
    case boolean(Bool)
    case string(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let colorValue = try? container.decode(GoveeColorValue.self) {
            self = .color(colorValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(GoveeCapabilityValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode GoveeCapabilityValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
            try container.encode(value)
        case .color(let value):
            try container.encode(value.rgbInteger)
        case .boolean(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}