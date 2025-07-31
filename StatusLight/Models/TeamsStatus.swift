//
//  TeamsStatus.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation

enum TeamsPresence: String, CaseIterable {
    case available = "Available"
    case away = "Away"
    case busy = "Busy"
    case doNotDisturb = "DoNotDisturb"
    case inACall = "InACall"
    case inAMeeting = "InAMeeting"
    case offline = "Offline"
    case unknown = "Unknown"
    
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .away:
            return "Away"
        case .busy:
            return "Busy"
        case .doNotDisturb:
            return "Do Not Disturb"
        case .inACall:
            return "In a Call"
        case .inAMeeting:
            return "In a Meeting"
        case .offline:
            return "Offline"
        case .unknown:
            return "Unknown"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .away:
            return "clock.fill"
        case .busy:
            return "minus.circle.fill"
        case .doNotDisturb:
            return "moon.fill"
        case .inACall:
            return "phone.fill"
        case .inAMeeting:
            return "video.fill"
        case .offline:
            return "circle"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

struct TeamsStatusInfo {
    let presence: TeamsPresence
    let activity: String?
    let lastActiveTime: Date?
    let statusMessage: String?
}