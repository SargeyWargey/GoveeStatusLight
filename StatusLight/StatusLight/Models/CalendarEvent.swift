//
//  CalendarEvent.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let subject: String
    let startTime: Date
    let endTime: Date
    let isAllDay: Bool
    let showAs: BusyStatus
    let isRecurring: Bool
    let meetingType: MeetingType
    let attendees: [Attendee]
    let location: String?
    let webLink: String?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var isCurrentlyActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var minutesUntilStart: Int {
        let now = Date()
        let interval = startTime.timeIntervalSince(now)
        return max(0, Int(interval / 60))
    }
    
    var isUpcoming: Bool {
        startTime > Date()
    }
}

enum BusyStatus: String, Codable, CaseIterable {
    case free = "free"
    case tentative = "tentative"
    case busy = "busy"
    case oof = "oof"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .tentative:
            return "Tentative"
        case .busy:
            return "Busy"
        case .oof:
            return "Out of Office"
        case .unknown:
            return "Unknown"
        }
    }
}

enum MeetingType: Codable {
    case shortMeeting // < 30 minutes
    case standardMeeting // 30-60 minutes
    case longMeeting // > 60 minutes
    case allDay
    
    init(duration: TimeInterval, isAllDay: Bool) {
        if isAllDay {
            self = .allDay
        } else if duration < 30 * 60 {
            self = .shortMeeting
        } else if duration <= 60 * 60 {
            self = .standardMeeting
        } else {
            self = .longMeeting
        }
    }
    
    var displayName: String {
        switch self {
        case .shortMeeting:
            return "Quick Meeting"
        case .standardMeeting:
            return "Standard Meeting"
        case .longMeeting:
            return "Long Meeting"
        case .allDay:
            return "All Day Event"
        }
    }
}

struct Attendee: Codable {
    let name: String?
    let email: String
    let responseStatus: ResponseStatus
}

enum ResponseStatus: String, Codable {
    case none = "none"
    case organizer = "organizer"
    case tentativelyAccepted = "tentativelyAccepted"
    case accepted = "accepted"
    case declined = "declined"
    case notResponded = "notResponded"
}

enum MeetingCountdownStage: CaseIterable {
    case fifteenMinutes
    case fiveMinutes
    case oneMinute
    case active
    
    var minutes: Int {
        switch self {
        case .fifteenMinutes:
            return 15
        case .fiveMinutes:
            return 5
        case .oneMinute:
            return 1
        case .active:
            return 0
        }
    }
    
    var displayName: String {
        switch self {
        case .fifteenMinutes:
            return "15 minutes until meeting"
        case .fiveMinutes:
            return "5 minutes until meeting"
        case .oneMinute:
            return "1 minute until meeting"
        case .active:
            return "Meeting in progress"
        }
    }
}