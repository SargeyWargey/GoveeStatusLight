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
    private var storedSelectedDeviceIds: [String]?
    private var storedDeviceStates: [String: Bool]?
    
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
            await loadDeviceStates()
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
            saveSelectedDevices()
        }
    }
    
    func removeDevice(_ device: GoveeDevice) {
        selectedDevices.removeAll { $0.id == device.id }
        saveSelectedDevices()
    }
    
    func toggleDeviceSelection(_ device: GoveeDevice) {
        if selectedDevices.contains(where: { $0.id == device.id }) {
            removeDevice(device)
        } else {
            addDevice(device)
        }
        saveSelectedDevices()
    }
    
    func toggleDeviceActive(_ device: GoveeDevice) async {
        guard let index = selectedDevices.firstIndex(where: { $0.id == device.id }) else { return }
        
        selectedDevices[index].isActive.toggle()
        let newState = selectedDevices[index].isActive
        
        // Send power command to device
        do {
            try await goveeService.controlDevice(device, power: newState)
            print("✅ StatusLightViewModel: Device \(device.deviceName) power set to \(newState)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to toggle \(device.deviceName): \(error.localizedDescription)"
            }
            // Revert the state change on failure
            selectedDevices[index].isActive.toggle()
        }
        
        saveDeviceStates()
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
                
                // Try to restore previously selected devices first
                if let storedIds = self?.storedSelectedDeviceIds, !storedIds.isEmpty {
                    self?.restoreDeviceSelection(from: devices)
                } else if self?.selectedDevices.isEmpty == true && self?.hasStoredDeviceSelection() == false {
                    // Only auto-select devices if no stored selection and none currently selected
                    let colorDevices = devices.filter { device in
                        device.capabilities.contains { capability in
                            capability.type.contains("color_setting")
                        }
                    }
                    print("🎨 StatusLightViewModel: Auto-selecting \(colorDevices.count) color-capable devices")
                    self?.selectedDevices = colorDevices
                    self?.saveSelectedDevices()
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
            
            print("🎨 StatusLightViewModel: Color changed! Sending commands to active devices...")
            print("🎨 TERMINAL COLOR LOG: Lights changing from RGB(\(currentLightColor?.r ?? 0),\(currentLightColor?.g ?? 0),\(currentLightColor?.b ?? 0)) to RGB(\(targetColor.r),\(targetColor.g),\(targetColor.b))")
            
            // Update only active selected devices
            let activeDevices = selectedDevices.filter { $0.isActive }
            print("💡 StatusLightViewModel: Updating \(activeDevices.count) active devices out of \(selectedDevices.count) selected")
            
            for device in activeDevices {
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
    
    // MARK: - Device State Persistence
    private func saveSelectedDevices() {
        do {
            let deviceIds = selectedDevices.map { $0.id }
            let data = try JSONEncoder().encode(deviceIds)
            if let jsonString = String(data: data, encoding: .utf8) {
                try KeychainService.store(jsonString, forAccount: KeychainService.Accounts.selectedDevices)
                print("💾 StatusLightViewModel: Saved \(deviceIds.count) selected device IDs")
            }
        } catch {
            print("❌ StatusLightViewModel: Failed to save selected devices: \(error.localizedDescription)")
        }
    }
    
    private func saveDeviceStates() {
        do {
            let deviceStates = selectedDevices.reduce(into: [String: Bool]()) { result, device in
                result[device.id] = device.isActive
            }
            let data = try JSONEncoder().encode(deviceStates)
            if let jsonString = String(data: data, encoding: .utf8) {
                try KeychainService.store(jsonString, forAccount: KeychainService.Accounts.deviceStates)
                print("💾 StatusLightViewModel: Saved device states for \(deviceStates.count) devices")
            }
        } catch {
            print("❌ StatusLightViewModel: Failed to save device states: \(error.localizedDescription)")
        }
    }
    
    private func loadDeviceStates() async {
        do {
            if let savedSelection = try KeychainService.retrieve(forAccount: KeychainService.Accounts.selectedDevices),
               let data = savedSelection.data(using: .utf8) {
                let deviceIds = try JSONDecoder().decode([String].self, from: data)
                print("📱 StatusLightViewModel: Loaded \(deviceIds.count) selected device IDs from storage")
                
                // Store the IDs to use when devices become available
                await MainActor.run {
                    self.storedSelectedDeviceIds = deviceIds
                }
            }
            
            if let savedStates = try KeychainService.retrieve(forAccount: KeychainService.Accounts.deviceStates),
               let data = savedStates.data(using: .utf8) {
                let deviceStates = try JSONDecoder().decode([String: Bool].self, from: data)
                print("📱 StatusLightViewModel: Loaded device states for \(deviceStates.count) devices")
                
                await MainActor.run {
                    self.storedDeviceStates = deviceStates
                }
            }
        } catch {
            print("❌ StatusLightViewModel: Failed to load device states: \(error.localizedDescription)")
        }
    }
    
    private func hasStoredDeviceSelection() -> Bool {
        do {
            return try KeychainService.retrieve(forAccount: KeychainService.Accounts.selectedDevices) != nil
        } catch {
            return false
        }
    }
    
    private func restoreDeviceSelection(from devices: [GoveeDevice]) {
        guard let storedIds = storedSelectedDeviceIds else { return }
        
        var restored: [GoveeDevice] = []
        for deviceId in storedIds {
            if let device = devices.first(where: { $0.id == deviceId }) {
                var deviceWithState = device
                // Restore the active state if we have it stored
                if let storedStates = storedDeviceStates {
                    deviceWithState.isActive = storedStates[deviceId] ?? true
                }
                restored.append(deviceWithState)
            }
        }
        
        if !restored.isEmpty {
            selectedDevices = restored
            print("🔄 StatusLightViewModel: Restored \(restored.count) selected devices with their states")
            for device in restored {
                print("  - \(device.deviceName): active=\(device.isActive)")
            }
        }
        
        // Clear the temporary storage
        storedSelectedDeviceIds = nil
        storedDeviceStates = nil
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