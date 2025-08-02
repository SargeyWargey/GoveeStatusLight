//
//  MeetingTracker.swift
//  StatusLight
//
//  Created by Claude on 8/1/25.
//

import Foundation
import SwiftUI

struct MeetingTrackerConfig: Codable {
    var isEnabled: Bool = false
    var countdownDurationMinutes: Int = 15
    var idleColor: GoveeColorValue = GoveeColorValue(r: 0, g: 255, b: 0) // Green
    var meetingColor: GoveeColorValue = GoveeColorValue(r: 255, g: 0, b: 0) // Red
    var assignedDeviceIds: Set<String> = []
    
    init() {}
}

struct MeetingTrackerState {
    let nextMeeting: CalendarEvent?
    let minutesUntilMeeting: Int
    let progressPercentage: Double // 0.0 to 1.0 representing how much of the bar should be meeting color
    let isActive: Bool
    
    init(nextMeeting: CalendarEvent?, countdownDurationMinutes: Int = 15) {
        self.nextMeeting = nextMeeting
        
        if let meeting = nextMeeting {
            self.minutesUntilMeeting = meeting.minutesUntilStart
            self.isActive = minutesUntilMeeting <= countdownDurationMinutes && meeting.isUpcoming
            
            if isActive {
                // Calculate progress: 0% at 15 minutes, 100% at 0 minutes
                let remainingTime = max(0, minutesUntilMeeting)
                self.progressPercentage = 1.0 - (Double(remainingTime) / Double(countdownDurationMinutes))
            } else {
                self.progressPercentage = 0.0
            }
        } else {
            self.minutesUntilMeeting = Int.max
            self.progressPercentage = 0.0
            self.isActive = false
        }
    }
}

enum DeviceAssignment: String, CaseIterable, Codable {
    case teamsStatus
    case meetingTracker
    case both
    
    var displayName: String {
        switch self {
        case .teamsStatus:
            return "Teams Status Only"
        case .meetingTracker:
            return "Meeting Tracker Only"
        case .both:
            return "Both Features"
        }
    }
}

struct DeviceConfiguration: Codable, Identifiable {
    let id: String // Device ID
    var assignment: DeviceAssignment = .teamsStatus
    
    init(deviceId: String, assignment: DeviceAssignment = .teamsStatus) {
        self.id = deviceId
        self.assignment = assignment
    }
}

class MeetingTracker: ObservableObject {
    @Published var config = MeetingTrackerConfig()
    @Published var currentState = MeetingTrackerState(nextMeeting: nil)
    @Published var deviceConfigurations: [String: DeviceConfiguration] = [:]
    
    private var upcomingEvents: [CalendarEvent] = []
    
    init() {
        loadStoredConfig()
        loadStoredDeviceAssignments()
    }
    
    func updateConfig(_ newConfig: MeetingTrackerConfig) {
        config = newConfig
        saveConfig()
        recalculateState()
    }
    
    func updateUpcomingEvents(_ events: [CalendarEvent]) {
        print("📋 MeetingTracker: Received \(events.count) total events for processing")
        
        // Log all received events
        for (index, event) in events.enumerated() {
            print("📋 MeetingTracker: Event \(index + 1): '\(event.subject)'")
            print("   - Start: \(event.startTime)")
            print("   - Is Upcoming: \(event.isUpcoming)")
            print("   - Minutes Until Start: \(event.minutesUntilStart)")
        }
        
        let previousUpcomingCount = upcomingEvents.count
        let previousNextMeeting = upcomingEvents.first?.subject
        
        upcomingEvents = events.filter { $0.isUpcoming }.sorted { $0.startTime < $1.startTime }
        
        print("📋 MeetingTracker: Filtered to \(upcomingEvents.count) upcoming events (was \(previousUpcomingCount))")
        
        // Log upcoming events after filtering
        for (index, event) in upcomingEvents.enumerated() {
            print("📋 MeetingTracker: Upcoming Event \(index + 1): '\(event.subject)' in \(event.minutesUntilStart) minutes")
        }
        
        let newNextMeeting = upcomingEvents.first?.subject
        if previousNextMeeting != newNextMeeting {
            print("📋 MeetingTracker: Next meeting changed from '\(previousNextMeeting ?? "none")' to '\(newNextMeeting ?? "none")'")
        }
        
        recalculateState()
    }
    
    func setDeviceAssignment(_ deviceId: String, assignment: DeviceAssignment) {
        deviceConfigurations[deviceId] = DeviceConfiguration(deviceId: deviceId, assignment: assignment)
        saveDeviceAssignments()
    }
    
    func getDeviceAssignment(_ deviceId: String) -> DeviceAssignment {
        return deviceConfigurations[deviceId]?.assignment ?? .teamsStatus
    }
    
    func getDevicesForMeetingTracker() -> Set<String> {
        return Set(deviceConfigurations.compactMap { key, config in
            config.assignment == .meetingTracker || config.assignment == .both ? key : nil
        })
    }
    
    func getDevicesForTeamsStatus() -> Set<String> {
        return Set(deviceConfigurations.compactMap { key, config in
            config.assignment == .teamsStatus || config.assignment == .both ? key : nil
        })
    }
    
    private func recalculateState() {
        let previousNextMeeting = currentState.nextMeeting?.subject
        let nextMeeting = upcomingEvents.first
        
        print("📊 MeetingTracker: Recalculating state...")
        print("📊 MeetingTracker: Previous next meeting: '\(previousNextMeeting ?? "none")'")
        print("📊 MeetingTracker: New next meeting: '\(nextMeeting?.subject ?? "none")'")
        print("📊 MeetingTracker: Countdown duration: \(config.countdownDurationMinutes) minutes")
        print("📊 MeetingTracker: Tracker enabled: \(config.isEnabled)")
        
        let previousState = currentState
        currentState = MeetingTrackerState(nextMeeting: nextMeeting, countdownDurationMinutes: config.countdownDurationMinutes)
        
        print("📊 MeetingTracker: State updated:")
        print("   - Is Active: \(currentState.isActive) (was \(previousState.isActive))")
        print("   - Progress: \(String(format: "%.1f", currentState.progressPercentage * 100))% (was \(String(format: "%.1f", previousState.progressPercentage * 100))%)")
        
        if let meeting = currentState.nextMeeting {
            print("   - Next Meeting: '\(meeting.subject)' in \(meeting.minutesUntilStart) minutes")
        } else {
            print("   - Next Meeting: none")
        }
    }
    
    func calculateLightStripColor(for deviceId: String, stripLength: Int = 100) -> [GoveeColorValue] {
        guard config.isEnabled,
              getDeviceAssignment(deviceId) == .meetingTracker || getDeviceAssignment(deviceId) == .both,
              currentState.isActive else {
            // Return idle color for entire strip
            return Array(repeating: config.idleColor, count: stripLength)
        }
        
        let meetingColorCount = Int(Double(stripLength) * currentState.progressPercentage)
        let idleColorCount = stripLength - meetingColorCount
        
        // Create gradient from left (idle color) to right (meeting color)
        var colors: [GoveeColorValue] = []
        colors.append(contentsOf: Array(repeating: config.idleColor, count: idleColorCount))
        colors.append(contentsOf: Array(repeating: config.meetingColor, count: meetingColorCount))
        
        return colors
    }
    
    func calculateSingleDeviceColor(for deviceId: String) -> GoveeColorValue {
        guard config.isEnabled,
              getDeviceAssignment(deviceId) == .meetingTracker || getDeviceAssignment(deviceId) == .both,
              currentState.isActive else {
            return config.idleColor
        }
        
        // For single color devices, blend between idle and meeting colors
        let progress = currentState.progressPercentage
        let r = Int(Double(config.idleColor.r) * (1 - progress) + Double(config.meetingColor.r) * progress)
        let g = Int(Double(config.idleColor.g) * (1 - progress) + Double(config.meetingColor.g) * progress)
        let b = Int(Double(config.idleColor.b) * (1 - progress) + Double(config.meetingColor.b) * progress)
        
        return GoveeColorValue(r: r, g: g, b: b)
    }
    
    // MARK: - Persistence
    private func saveConfig() {
        do {
            let data = try JSONEncoder().encode(config)
            if let jsonString = String(data: data, encoding: .utf8) {
                try KeychainService.store(jsonString, forAccount: KeychainService.Accounts.meetingTrackerConfig)
                print("💾 MeetingTracker: Saved config")
            }
        } catch {
            print("❌ MeetingTracker: Failed to save config: \(error.localizedDescription)")
        }
    }
    
    private func loadStoredConfig() {
        do {
            if let configString = try KeychainService.retrieve(forAccount: KeychainService.Accounts.meetingTrackerConfig),
               let data = configString.data(using: .utf8) {
                config = try JSONDecoder().decode(MeetingTrackerConfig.self, from: data)
                print("📱 MeetingTracker: Loaded stored config")
            }
        } catch {
            print("❌ MeetingTracker: Failed to load config: \(error.localizedDescription)")
        }
    }
    
    private func saveDeviceAssignments() {
        do {
            let data = try JSONEncoder().encode(deviceConfigurations)
            if let jsonString = String(data: data, encoding: .utf8) {
                try KeychainService.store(jsonString, forAccount: KeychainService.Accounts.deviceAssignments)
                print("💾 MeetingTracker: Saved device assignments for \(deviceConfigurations.count) devices")
            }
        } catch {
            print("❌ MeetingTracker: Failed to save device assignments: \(error.localizedDescription)")
        }
    }
    
    private func loadStoredDeviceAssignments() {
        do {
            if let assignmentsString = try KeychainService.retrieve(forAccount: KeychainService.Accounts.deviceAssignments),
               let data = assignmentsString.data(using: .utf8) {
                deviceConfigurations = try JSONDecoder().decode([String: DeviceConfiguration].self, from: data)
                print("📱 MeetingTracker: Loaded device assignments for \(deviceConfigurations.count) devices")
            }
        } catch {
            print("❌ MeetingTracker: Failed to load device assignments: \(error.localizedDescription)")
        }
    }
}