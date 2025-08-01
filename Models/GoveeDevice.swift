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
    let deviceType: String
    let capabilities: [DeviceCapability]
    var isConnected: Bool = false
    var lastUpdated: Date = Date()
}

struct DeviceCapability: Codable {
    let type: String
    let instance: String
    let parameters: [String: String]? // Changed from [String: Any] to [String: String]
    
    enum CodingKeys: String, CodingKey {
        case type, instance, parameters
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        instance = try container.decode(String.self, forKey: .instance)
        parameters = try container.decodeIfPresent([String: String].self, forKey: .parameters)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(instance, forKey: .instance)
        try container.encodeIfPresent(parameters, forKey: .parameters)
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
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}