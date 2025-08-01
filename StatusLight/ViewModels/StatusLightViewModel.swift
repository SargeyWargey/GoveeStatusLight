//
//  StatusLightViewModel.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class StatusLightViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTeamsStatus: TeamsStatusInfo?
    @Published var upcomingMeeting: CalendarEvent?
    @Published var availableDevices: [GoveeDevice] = []
    @Published var selectedDevices: [GoveeDevice] = []
    @Published var colorMapping = ColorMapping.default
    @Published var isTeamsConnected = false
    @Published var isGoveeConnected = false
    @Published var currentLightColor: GoveeColorValue?
    @Published var lastStatusChange: Date?
    @Published var errorMessage: String?
    @Published var isRefreshingDevices = false
    
    // MARK: - Services
    private let teamsService: TeamsServiceProtocol
    private let goveeService: GoveeServiceProtocol
    private let calendarService: CalendarServiceProtocol
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lightingTimer: Timer?
    
    // MARK: - Initialization
    init(
        teamsService: TeamsServiceProtocol = TeamsService(),
        goveeService: GoveeServiceProtocol = GoveeService(),
        calendarService: CalendarServiceProtocol = CalendarService()
    ) {
        self.teamsService = teamsService
        self.goveeService = goveeService
        self.calendarService = calendarService
        
        setupSubscriptions()
        startLightingEngine()
        
        // Initialize services
        Task {
            await goveeService.loadStoredAPIKey()
        }
    }
    
    deinit {
        lightingTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func authenticateTeams() async {
        do {
            try await teamsService.authenticate()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to authenticate with Teams: \(error.localizedDescription)"
            }
        }
    }
    
    func signOutFromTeams() async {
        do {
            try await teamsService.signOut()
            await MainActor.run {
                self.currentTeamsStatus = nil
                self.lastStatusChange = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to sign out from Teams: \(error.localizedDescription)"
            }
        }
    }
    
    func authenticateGovee(apiKey: String) async {
        do {
            try await goveeService.configureAPIKey(apiKey)
            try await goveeService.discoverDevices()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to authenticate with Govee: \(error.localizedDescription)"
            }
        }
    }
    
    func configureGoveeAPIKey(_ apiKey: String) async throws {
        do {
            try await goveeService.configureAPIKey(apiKey)
            // Don't automatically discover devices here - let user do it manually
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to configure Govee API key: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func testGoveeAPIKey() async {
        do {
            let isValid = try await goveeService.testAPIKey()
            await MainActor.run {
                if isValid {
                    self.errorMessage = "✅ Govee API key test successful!"
                } else {
                    self.errorMessage = "❌ Govee API key test failed - check your key"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Govee API key test failed: \(error.localizedDescription)"
            }
        }
    }
    
    func testGoveeAPIKey(_ apiKey: String) async {
        do {
            let isValid = try await goveeService.testTemporaryAPIKey(apiKey)
            await MainActor.run {
                if isValid {
                    self.errorMessage = "✅ Govee API key test successful!"
                } else {
                    self.errorMessage = "❌ Govee API key test failed - check your key"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Govee API key test failed: \(error.localizedDescription)"
            }
        }
    }
    
    func removeGoveeAPIKey() async throws {
        do {
            try await goveeService.removeAPIKey()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove Govee API key: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    private func refreshGoveeConnection() async {
        do {
            try await goveeService.discoverDevices()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh Govee connection: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshStatus() async {
        do {
            async let teamsRefresh: () = teamsService.refreshStatus()
            async let calendarRefresh: () = calendarService.refreshEvents()
            
            try await teamsRefresh
            try await calendarRefresh
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh status: \(error.localizedDescription)"
            }
        }
    }
    
    func updateColorMapping(_ newMapping: ColorMapping) {
        colorMapping = newMapping
        // Trigger immediate light update with new colors
        Task {
            await updateLights()
        }
    }
    
    func addDevice(_ device: GoveeDevice) {
        if !selectedDevices.contains(where: { $0.id == device.id }) {
            selectedDevices.append(device)
        }
    }
    
    func removeDevice(_ device: GoveeDevice) {
        selectedDevices.removeAll { $0.id == device.id }
    }
    
    func toggleDeviceSelection(_ device: GoveeDevice) {
        if selectedDevices.contains(where: { $0.id == device.id }) {
            removeDevice(device)
        } else {
            addDevice(device)
        }
    }
    
    func isDeviceSelected(_ device: GoveeDevice) -> Bool {
        return selectedDevices.contains(where: { $0.id == device.id })
    }
    
    func testLightColor(_ color: GoveeColorValue) async {
        for device in selectedDevices {
            do {
                try await goveeService.controlDevice(device, color: color)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to test color on \(device.deviceName): \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        // Teams status subscription
        teamsService.currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.currentTeamsStatus = status
                if status != nil {
                    self?.lastStatusChange = Date()
                }
            }
            .store(in: &cancellables)
        
        // Teams connection status
        teamsService.isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isTeamsConnected = isAuthenticated
            }
            .store(in: &cancellables)
        
        // Govee connection status
        goveeService.connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isGoveeConnected = status == .connected
            }
            .store(in: &cancellables)
        
        // Govee configuration status
        goveeService.isConfigured
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConfigured in
                if isConfigured && self?.isGoveeConnected == false {
                    // API key is configured but connection failed, update status
                    Task {
                        await self?.refreshGoveeConnection()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Calendar events subscription
        calendarService.upcomingEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                // Get the next upcoming meeting
                self?.upcomingMeeting = events.first { $0.isUpcoming && $0.showAs == .busy }
            }
            .store(in: &cancellables)
        
        // Available devices subscription
        goveeService.devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                print("📱 StatusLightViewModel: Received \(devices.count) devices from GoveeService")
                for device in devices {
                    print("  - \(device.deviceName) (\(device.sku)) - Connected: \(device.isConnected)")
                }
                
                // Update available devices list
                self?.availableDevices = devices
                
                // Auto-select RGBICWW devices if none are selected
                if self?.selectedDevices.isEmpty == true {
                    let colorDevices = devices.filter { device in
                        device.capabilities.contains { capability in
                            capability.type.contains("color_setting")
                        }
                    }
                    print("🎨 StatusLightViewModel: Auto-selecting \(colorDevices.count) color-capable devices")
                    self?.selectedDevices = colorDevices
                }
            }
            .store(in: &cancellables)
    }
    
    private func startLightingEngine() {
        // Update lights every 15 seconds to catch status changes
        lightingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateLights()
            }
        }
        
        // Initial light update
        Task {
            await updateLights()
        }
    }
    
    private func updateLights() async {
        guard !selectedDevices.isEmpty else { 
            print("💡 StatusLightViewModel: No selected devices to update")
            return 
        }
        
        let targetColor = determineTargetColor()
        
        print("💡 StatusLightViewModel: Current color: \(currentLightColor?.r ?? 0), \(currentLightColor?.g ?? 0), \(currentLightColor?.b ?? 0)")
        print("💡 StatusLightViewModel: Target color: \(targetColor.r), \(targetColor.g), \(targetColor.b)")
        print("💡 StatusLightViewModel: Selected devices: \(selectedDevices.count)")
        for device in selectedDevices {
            print("  - \(device.deviceName) (Connected: \(device.isConnected))")
        }
        
        // Only update if color has changed
        if currentLightColor != targetColor {
            currentLightColor = targetColor
            
            print("🎨 StatusLightViewModel: Color changed! Sending commands to \(selectedDevices.count) devices...")
            print("🎨 TERMINAL COLOR LOG: Lights changing from RGB(\(currentLightColor?.r ?? 0),\(currentLightColor?.g ?? 0),\(currentLightColor?.b ?? 0)) to RGB(\(targetColor.r),\(targetColor.g),\(targetColor.b))")
            
            // Update all selected devices
            for device in selectedDevices {
                do {
                    print("📡 StatusLightViewModel: Sending color RGB(\(targetColor.r),\(targetColor.g),\(targetColor.b)) to \(device.deviceName)")
                    try await goveeService.controlDevice(device, color: targetColor)
                    print("✅ TERMINAL COLOR LOG: Successfully changed \(device.deviceName) to RGB(\(targetColor.r),\(targetColor.g),\(targetColor.b))")
                } catch {
                    print("❌ StatusLightViewModel: Failed to update \(device.deviceName): \(error.localizedDescription)")
                    await MainActor.run {
                        self.errorMessage = "Failed to update \(device.deviceName): \(error.localizedDescription)"
                    }
                }
            }
        } else {
            print("💡 StatusLightViewModel: Color unchanged RGB(\(targetColor.r),\(targetColor.g),\(targetColor.b)), skipping update")
        }
    }
    
    private func determineTargetColor() -> GoveeColorValue {
        // Priority system for determining light color
        print("🎯 StatusLightViewModel: Determining target color...")
        
        // 1. Meeting countdown (highest priority)
        if let meeting = upcomingMeeting, meeting.isUpcoming {
            let minutesUntil = meeting.minutesUntilStart
            print("📅 StatusLightViewModel: Upcoming meeting found - \(minutesUntil) minutes until start")
            
            if meeting.isCurrentlyActive {
                let color = colorMapping.colorForMeetingCountdown(.active)
                print("🔴 StatusLightViewModel: Using ACTIVE meeting color: RGB(\(color.r),\(color.g),\(color.b))")
                return color
            } else if minutesUntil <= 1 {
                let color = colorMapping.colorForMeetingCountdown(.oneMinute)
                print("🟠 StatusLightViewModel: Using 1-minute warning color: RGB(\(color.r),\(color.g),\(color.b))")
                return color
            } else if minutesUntil <= 5 {
                let color = colorMapping.colorForMeetingCountdown(.fiveMinutes)
                print("🟡 StatusLightViewModel: Using 5-minute warning color: RGB(\(color.r),\(color.g),\(color.b))")
                return color
            } else if minutesUntil <= 15 {
                let color = colorMapping.colorForMeetingCountdown(.fifteenMinutes)
                print("🔵 StatusLightViewModel: Using 15-minute warning color: RGB(\(color.r),\(color.g),\(color.b))")
                return color
            }
        } else {
            print("📅 StatusLightViewModel: No upcoming meetings")
        }
        
        // 2. Teams status (medium priority)
        if let teamsStatus = currentTeamsStatus {
            let color = colorMapping.colorForTeamsStatus(teamsStatus.presence)
            print("👤 StatusLightViewModel: Using Teams status color for \(teamsStatus.presence.displayName): RGB(\(color.r),\(color.g),\(color.b))")
            return color
        } else {
            print("👤 StatusLightViewModel: No Teams status available")
        }
        
        // 3. Default color (lowest priority)
        let color = colorMapping.colorForTeamsStatus(.unknown)
        print("❓ StatusLightViewModel: Using default color: RGB(\(color.r),\(color.g),\(color.b))")
        return color
    }
    
    func refreshGoveeDevices() async {
        await MainActor.run {
            self.isRefreshingDevices = true
            self.errorMessage = nil
        }
        
        do {
            print("🔄 Starting refresh: Teams status + Govee devices...")
            
            // Refresh both Teams status and Govee devices in parallel
            async let teamsRefresh: () = teamsService.refreshStatus()
            async let goveeRefresh: () = goveeService.discoverDevices()
            
            try await teamsRefresh
            print("✅ Teams status refresh completed successfully")
            
            try await goveeRefresh
            print("✅ Govee device discovery completed successfully")
            
            // Check if devices were loaded - we can't access .value directly on AnyPublisher
            print("📱 Device discovery completed - check the subscription logs above")
            
            await MainActor.run {
                self.isRefreshingDevices = false
            }
        } catch {
            print("❌ Refresh failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to refresh: \(error.localizedDescription)"
                self.isRefreshingDevices = false
            }
        }
    }
}

// MARK: - Calendar Service
protocol CalendarServiceProtocol {
    var upcomingEvents: AnyPublisher<[CalendarEvent], Never> { get }
    func refreshEvents() async throws
}

class CalendarService: CalendarServiceProtocol {
    private let microsoftGraphService = MicrosoftGraphService()
    
    var upcomingEvents: AnyPublisher<[CalendarEvent], Never> {
        microsoftGraphService.upcomingEvents
    }
    
    func refreshEvents() async throws {
        try await microsoftGraphService.refreshCalendarEvents()
    }
}