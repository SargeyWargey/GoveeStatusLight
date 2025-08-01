//
//  ColorMapping.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import SwiftUI

struct ColorMapping: Codable {
    var teamsStatusColors: [String: GoveeColorValue]
    var meetingCountdownColors: [String: GoveeColorValue]
    var meetingTypeColors: [String: GoveeColorValue]
    
    private enum CodingKeys: String, CodingKey {
        case teamsStatusColors, meetingCountdownColors, meetingTypeColors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamsStatusColors = try container.decode([String: GoveeColorValue].self, forKey: .teamsStatusColors)
        meetingCountdownColors = try container.decode([String: GoveeColorValue].self, forKey: .meetingCountdownColors)
        meetingTypeColors = try container.decode([String: GoveeColorValue].self, forKey: .meetingTypeColors)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(teamsStatusColors, forKey: .teamsStatusColors)
        try container.encode(meetingCountdownColors, forKey: .meetingCountdownColors)
        try container.encode(meetingTypeColors, forKey: .meetingTypeColors)
    }
    
    // Convenience initializer for creating with enum keys
    init(
        teamsStatusColors: [TeamsPresence: GoveeColorValue],
        meetingCountdownColors: [MeetingCountdownStage: GoveeColorValue],
        meetingTypeColors: [MeetingType: GoveeColorValue]
    ) {
        self.teamsStatusColors = Dictionary(uniqueKeysWithValues: teamsStatusColors.map { ($0.key.rawValue, $0.value) })
        self.meetingCountdownColors = Dictionary(uniqueKeysWithValues: meetingCountdownColors.map { (String(describing: $0.key), $0.value) })
        self.meetingTypeColors = Dictionary(uniqueKeysWithValues: meetingTypeColors.map { (String(describing: $0.key), $0.value) })
    }
    
    static let `default` = ColorMapping(
        teamsStatusColors: [
            .available: GoveeColorValue(r: 0, g: 255, b: 0),      // Green
            .away: GoveeColorValue(r: 255, g: 255, b: 0),         // Yellow
            .busy: GoveeColorValue(r: 255, g: 0, b: 0),           // Red
            .doNotDisturb: GoveeColorValue(r: 128, g: 0, b: 128), // Purple
            .inACall: GoveeColorValue(r: 0, g: 100, b: 255),      // Blue
            .inAMeeting: GoveeColorValue(r: 255, g: 165, b: 0),   // Orange
            .offline: GoveeColorValue(r: 128, g: 128, b: 128),    // Gray
            .unknown: GoveeColorValue(r: 255, g: 255, b: 255)     // White
        ],
        meetingCountdownColors: [
            .fifteenMinutes: GoveeColorValue(r: 255, g: 255, b: 0),  // Yellow
            .fiveMinutes: GoveeColorValue(r: 255, g: 165, b: 0),     // Orange
            .oneMinute: GoveeColorValue(r: 255, g: 0, b: 0),         // Red
            .active: GoveeColorValue(r: 128, g: 0, b: 128)           // Purple
        ],
        meetingTypeColors: [
            .shortMeeting: GoveeColorValue(r: 0, g: 255, b: 255),    // Cyan
            .standardMeeting: GoveeColorValue(r: 0, g: 100, b: 255), // Blue
            .longMeeting: GoveeColorValue(r: 128, g: 0, b: 255),     // Violet
            .allDay: GoveeColorValue(r: 255, g: 20, b: 147)          // Deep Pink
        ]
    )
    
    func colorForTeamsStatus(_ status: TeamsPresence) -> GoveeColorValue {
        return teamsStatusColors[status.rawValue] ?? GoveeColorValue(r: 255, g: 255, b: 255)
    }
    
    func colorForMeetingCountdown(_ stage: MeetingCountdownStage) -> GoveeColorValue {
        return meetingCountdownColors[String(describing: stage)] ?? GoveeColorValue(r: 255, g: 255, b: 255)
    }
    
    func colorForMeetingType(_ type: MeetingType) -> GoveeColorValue {
        return meetingTypeColors[String(describing: type)] ?? GoveeColorValue(r: 255, g: 255, b: 255)
    }
}

enum LightingPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}

struct LightingRule {
    let id = UUID()
    let name: String
    let priority: LightingPriority
    let condition: LightingCondition
    let color: GoveeColorValue
    let isEnabled: Bool
    
    func matches(teamsStatus: TeamsPresence?, upcomingMeeting: CalendarEvent?) -> Bool {
        return condition.matches(teamsStatus: teamsStatus, upcomingMeeting: upcomingMeeting)
    }
}

enum LightingCondition {
    case teamsStatus(TeamsPresence)
    case meetingCountdown(MeetingCountdownStage)
    case meetingActive(MeetingType)
    case timeOfDay(startHour: Int, endHour: Int)
    case combined([LightingCondition])
    
    func matches(teamsStatus: TeamsPresence?, upcomingMeeting: CalendarEvent?) -> Bool {
        switch self {
        case .teamsStatus(let status):
            return teamsStatus == status
            
        case .meetingCountdown(let stage):
            guard let meeting = upcomingMeeting else { return false }
            let minutesUntil = meeting.minutesUntilStart
            return minutesUntil <= stage.minutes && minutesUntil > 0
            
        case .meetingActive(let type):
            guard let meeting = upcomingMeeting else { return false }
            return meeting.isCurrentlyActive && meeting.meetingType == type
            
        case .timeOfDay(let startHour, let endHour):
            let currentHour = Calendar.current.component(.hour, from: Date())
            return currentHour >= startHour && currentHour < endHour
            
        case .combined(let conditions):
            return conditions.allSatisfy { $0.matches(teamsStatus: teamsStatus, upcomingMeeting: upcomingMeeting) }
        }
    }
}