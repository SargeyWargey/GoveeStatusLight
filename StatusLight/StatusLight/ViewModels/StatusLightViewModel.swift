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
        // Update lights every 30 seconds to catch status changes
        lightingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
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
        guard !selectedDevices.isEmpty else { return }
        
        let targetColor = determineTargetColor()
        
        // Only update if color has changed
        if currentLightColor != targetColor {
            currentLightColor = targetColor
            
            // Update all selected devices
            for device in selectedDevices {
                do {
                    try await goveeService.controlDevice(device, color: targetColor)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to update \(device.deviceName): \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func determineTargetColor() -> GoveeColorValue {
        // Priority system for determining light color
        
        // 1. Meeting countdown (highest priority)
        if let meeting = upcomingMeeting, meeting.isUpcoming {
            let minutesUntil = meeting.minutesUntilStart
            
            if meeting.isCurrentlyActive {
                return colorMapping.colorForMeetingCountdown(.active)
            } else if minutesUntil <= 1 {
                return colorMapping.colorForMeetingCountdown(.oneMinute)
            } else if minutesUntil <= 5 {
                return colorMapping.colorForMeetingCountdown(.fiveMinutes)
            } else if minutesUntil <= 15 {
                return colorMapping.colorForMeetingCountdown(.fifteenMinutes)
            }
        }
        
        // 2. Teams status (medium priority)
        if let teamsStatus = currentTeamsStatus {
            return colorMapping.colorForTeamsStatus(teamsStatus.presence)
        }
        
        // 3. Default color (lowest priority)
        return colorMapping.colorForTeamsStatus(.unknown)
    }
    
    func refreshGoveeDevices() async {
        await MainActor.run {
            self.isRefreshingDevices = true
            self.errorMessage = nil
        }
        
        do {
            print("🔍 Starting Govee device discovery...")
            try await goveeService.discoverDevices()
            print("✅ Govee device discovery completed successfully")
            
            // Check if devices were loaded - we can't access .value directly on AnyPublisher
            print("📱 Device discovery completed - check the subscription logs above")
            
            await MainActor.run {
                self.isRefreshingDevices = false
            }
        } catch {
            print("❌ Govee device discovery failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to refresh Govee devices: \(error.localizedDescription)"
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