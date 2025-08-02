//
//  SettingsView.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/31/25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    @State private var goveeAPIKey: String = ""
    @State private var isConfiguring = false
    @State private var showingAPIKeyInfo = false
    @State private var configurationMessage: String = ""
    @State private var showingSuccess = false
    @FocusState private var isAPIKeyFieldFocused: Bool
    @State private var isAuthenticatingTeams = false
    @State private var showingSettingsWindow = false
    @State private var settingsWindow: NSWindow?
    @State private var windowDelegate: SettingsWindowDelegate?
    @State private var tempPollingInterval: String = ""
    @State private var updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    
    private var statusOverview: some View {
        GroupBox("Status Overview") {
            HStack(spacing: 20) {
                // Teams Status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(viewModel.isTeamsConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text("Teams")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    if let teamsStatus = viewModel.currentTeamsStatus {
                        HStack {
                            Image(systemName: teamsStatus.presence.systemImageName)
                                .foregroundColor(colorForStatus(teamsStatus.presence))
                                .font(.caption)
                            Text(teamsStatus.presence.displayName)
                                .font(.caption)
                        }
                    } else {
                        Text("No status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Govee Status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(viewModel.isGoveeConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text("Govee")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(viewModel.selectedDevices.isEmpty ? "No devices" : "\(viewModel.selectedDevices.count) devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private var goveeConfigurationSection: some View {
        GroupBox("Govee API Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("API Key Status:")
                        .fontWeight(.medium)
                    Spacer()
                    statusIndicator
                }
                
                if !viewModel.isGoveeConnected {
                    goveeNotConnectedView
                } else {
                    goveeConnectedView
                }
                
                if !configurationMessage.isEmpty {
                    Text(configurationMessage)
                        .font(.caption)
                        .foregroundColor(showingSuccess ? .green : .red)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }
    
    private var goveeNotConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your Govee API Key:")
                .font(.subheadline)
            
            HStack {
                SecureField("API Key", text: $goveeAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isConfiguring)
                    .focused($isAPIKeyFieldFocused)
                
                Button(action: {
                    showingAPIKeyInfo = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
                .help("How to get your Govee API Key")
            }
            
            HStack {
                Button("Configure API Key") {
                    configureGoveeAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConfiguring)
                
                Button("Test API Key") {
                    testGoveeAPIKey()
                }
                .buttonStyle(.bordered)
                .disabled(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConfiguring)
                
                if isConfiguring {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }
    
    private var goveeConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API Key configured successfully")
                    .foregroundColor(.green)
            }
            
            Button("Remove API Key") {
                removeGoveeAPIKey()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var teamsIntegrationSection: some View {
        GroupBox("Microsoft Teams Integration") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Teams Status:")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isTeamsConnected ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isTeamsConnected ? "Connected" : "Mock Data")
                            .font(.caption)
                    }
                }
                
                // Teams Status Indicator
                if let teamsStatus = viewModel.currentTeamsStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Presence:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            // Status indicator light matching the actual device color
                            Circle()
                                .fill(colorForStatus(teamsStatus.presence))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(teamsStatus.presence.displayName)
                                    .fontWeight(.medium)
                                
                                if let activity = teamsStatus.activity, !activity.isEmpty {
                                    Text(activity)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let lastUpdate = viewModel.lastStatusChange {
                                    Text("Updated \(timeAgoFormatter.string(for: lastUpdate) ?? "now")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(colorForStatus(teamsStatus.presence).opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                        Text("No Teams status available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                }
                
                if !viewModel.isTeamsConnected {
                    teamsNotConnectedView
                } else {
                    teamsConnectedView
                }
                
                if viewModel.errorMessage?.contains("Client ID not configured") == true {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ Azure Configuration Required")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text("To use live Microsoft Teams data, you need to configure the Azure app registration. The current setup uses a placeholder Client ID.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Microsoft Teams integration provides real-time presence and calendar data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Teams Polling Interval Configuration (shown whether connected or not)
                teamsPollingIntervalView
            }
            .padding()
        }
    }
    
    private var teamsNotConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in to Microsoft Teams to get live presence data and calendar integration.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Sign in to Microsoft Teams") {
                authenticateWithTeams()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticatingTeams)
            
            if isAuthenticatingTeams {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Authenticating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var teamsConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Microsoft Teams")
                    .foregroundColor(.green)
            }
            
            Text("Receiving live presence and calendar data")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Sign Out") {
                signOutFromTeams()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var devicesSection: some View {
        GroupBox("Govee Devices") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Available Devices")
                        .fontWeight(.medium)
                    Spacer()
                    if viewModel.isGoveeConnected {
                        HStack {
                            Button("Refresh Devices") {
                                refreshGoveeDevices()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isRefreshingDevices)
                            
                            if viewModel.isRefreshingDevices {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                
                if viewModel.availableDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No devices discovered yet")
                            .foregroundColor(.secondary)
                        if viewModel.isGoveeConnected {
                            Text("Click 'Refresh Devices' to discover your Govee lights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Configure your Govee API key to discover devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if !viewModel.selectedDevices.isEmpty {
                            Text("Use the Settings window for device function assignment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                        
                        ForEach(viewModel.availableDevices, id: \.id) { device in
                            HStack {
                                Button(action: {
                                    viewModel.toggleDeviceSelection(device)
                                }) {
                                    HStack {
                                        Image(systemName: viewModel.isDeviceSelected(device) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.isDeviceSelected(device) ? .green : .secondary)
                                        Text(device.deviceName)
                                            .font(.system(size: 12, weight: .medium))
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                if viewModel.isDeviceSelected(device) {
                                    Button(action: {
                                        Task {
                                            await viewModel.toggleDeviceActive(device)
                                        }
                                    }) {
                                        Image(systemName: device.isActive ? "power.circle.fill" : "power.circle")
                                            .foregroundColor(device.isActive ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            statusOverview
            
            // Buttons moved under status box
            HStack(spacing: 8) {
                Button("Refresh") {
                    Task {
                        await viewModel.refreshGoveeDevices()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Settings") {
                    showingSettingsWindow = true
                    // Dismiss the menubar window
                    NSApplication.shared.keyWindow?.orderOut(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Error Display
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .onAppear {
                        // Auto-dismiss error after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            viewModel.errorMessage = nil
                        }
                    }
            }
        }
        .padding()
        .task {
            // Initial setup when settings view appears
            await viewModel.refreshGoveeDevices()
        }
        .background(
            EmptyView()
                .sheet(isPresented: $showingSettingsWindow) {
                    EmptyView()
                }
        )
        .onChange(of: showingSettingsWindow) {
            if showingSettingsWindow {
                openSettingsWindow()
            }
        }
        .alert("How to Get Your Govee API Key", isPresented: $showingAPIKeyInfo) {
            Button("OK") { }
        } message: {
            Text("1. Open the Govee Home App\n2. Go to Profile → Settings\n3. Select 'Apply for API Key'\n4. Fill in your information\n5. Check your email for the API key\n\nNote: You can only have one active API key at a time.")
        }
        .onReceive(updateTimer) { _ in
            // This triggers view refresh every second to update relative time
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isGoveeConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isGoveeConnected ? "Connected" : "Not Configured")
                .font(.caption)
        }
    }
    
    private func configureGoveeAPIKey() {
        isConfiguring = true
        configurationMessage = ""
        showingSuccess = false
        
        Task {
            do {
                try await viewModel.configureGoveeAPIKey(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
                
                await MainActor.run {
                    configurationMessage = "API Key configured successfully!"
                    showingSuccess = true
                    goveeAPIKey = "" // Clear the field for security
                    isConfiguring = false
                }
                
                // Auto-clear success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    configurationMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to configure API Key: \(error.localizedDescription)"
                    showingSuccess = false
                    isConfiguring = false
                }
                
                // Auto-clear error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    configurationMessage = ""
                }
            }
        }
    }
    
    private func testGoveeAPIKey() {
        isConfiguring = true
        configurationMessage = ""
        showingSuccess = false
        
        Task {
            await viewModel.testGoveeAPIKey(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isConfiguring = false
            }
        }
    }
    
    private func removeGoveeAPIKey() {
        Task {
            do {
                try await viewModel.removeGoveeAPIKey()
                await MainActor.run {
                    configurationMessage = "API Key removed successfully"
                    showingSuccess = true
                }
                
                // Auto-clear message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    configurationMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to remove API Key: \(error.localizedDescription)"
                    showingSuccess = false
                }
                
                // Auto-clear error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    configurationMessage = ""
                }
            }
        }
    }
    
    private func authenticateWithTeams() {
        isAuthenticatingTeams = true
        
        Task {
            await viewModel.authenticateTeams()
            
            await MainActor.run {
                isAuthenticatingTeams = false
            }
        }
    }
    
    private func signOutFromTeams() {
        Task {
            await viewModel.signOutFromTeams()
        }
    }
    
    private func refreshGoveeDevices() {
        Task {
            await viewModel.refreshGoveeDevices()
        }
    }
    
    
    
    private func colorForStatus(_ status: TeamsPresence) -> Color {
        let goveeColor = viewModel.colorMapping.colorForTeamsStatus(status)
        return goveeColor.color
    }
    
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    private func updatePollingInterval() {
        if let interval = Double(tempPollingInterval) {
            viewModel.updateTeamsPollingInterval(interval)
        }
    }
    
    
    private var teamsPollingIntervalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Polling Interval Configuration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Text("Check Teams status every:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: $tempPollingInterval)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onSubmit {
                            updatePollingInterval()
                        }
                        .onAppear {
                            tempPollingInterval = String(Int(viewModel.teamsPollingInterval))
                        }
                    
                    Text("seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Update") {
                        updatePollingInterval()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(tempPollingInterval.isEmpty)
                }
                
                // API Usage Recommendations
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 API Usage Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text("• Minimum recommended: 15 seconds (Microsoft Graph rate limits)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("• For aggressive monitoring: 5-10 seconds (use sparingly)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("• Current: \(Int(viewModel.teamsPollingInterval)) seconds (\(apiUsageDescription))")
                            .font(.caption2)
                            .foregroundColor(apiUsageColor)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var apiUsageDescription: String {
        let interval = viewModel.teamsPollingInterval
        if interval >= 30 {
            return "Conservative"
        } else if interval >= 15 {
            return "Recommended"
        } else if interval >= 5 {
            return "Aggressive"
        } else {
            return "Very Aggressive"
        }
    }
    
    private var apiUsageColor: Color {
        let interval = viewModel.teamsPollingInterval
        if interval >= 15 {
            return .green
        } else if interval >= 5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func openSettingsWindow() {
        // If window already exists, bring it to focus instead of recreating
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Settings"
        newWindow.isReleasedWhenClosed = false // Prevent crash when window closes
        
        // Enhanced window appearance for native macOS look
        newWindow.styleMask.insert(.fullSizeContentView)
        newWindow.hasShadow = true
        newWindow.alphaValue = 0.98 // Slight transparency for better integration
        
        // Create a window delegate to handle window closing
        let delegate = SettingsWindowDelegate {
            self.settingsWindow = nil
            self.showingSettingsWindow = false
            self.windowDelegate = nil
        }
        newWindow.delegate = delegate
        windowDelegate = delegate
        
        newWindow.contentView = NSHostingView(
            rootView: SettingsWindowView(viewModel: viewModel)
        )
        
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Store the window reference
        settingsWindow = newWindow
        showingSettingsWindow = false
    }
}

// Window delegate to handle window closing
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

struct SettingsWindowView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    @State private var goveeAPIKey: String = ""
    @State private var isConfiguring = false
    @State private var showingAPIKeyInfo = false
    @State private var configurationMessage: String = ""
    @State private var showingSuccess = false
    @FocusState private var isAPIKeyFieldFocused: Bool
    @State private var isAuthenticatingTeams = false
    @State private var tempPollingInterval: String = ""
    @State private var updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Settings Header
                HStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.top, 8)
                
                goveeConfigurationSection
                teamsIntegrationSection
                meetingTrackerSection
                devicesSection
                
                // Error Display
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 8)
                        .onAppear {
                            // Auto-dismiss error after 5 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                viewModel.errorMessage = nil
                            }
                        }
                }
            }
            .padding(20)
        }
        .background(Color(.windowBackgroundColor))
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .alert("How to Get Your Govee API Key", isPresented: $showingAPIKeyInfo) {
            Button("OK") { }
        } message: {
            Text("1. Open the Govee Home App\n2. Go to Profile → Settings\n3. Select 'Apply for API Key'\n4. Fill in your information\n5. Check your email for the API key\n\nNote: You can only have one active API key at a time.")
        }
        .onReceive(updateTimer) { _ in
            // This triggers view refresh every second to update relative time
        }
    }
    
    // Copy the configuration sections from the main view
    private var goveeConfigurationSection: some View {
        GroupBox("Govee API Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("API Key Status:")
                        .fontWeight(.medium)
                    Spacer()
                    statusIndicator
                }
                
                if !viewModel.isGoveeConnected {
                    goveeNotConnectedView
                } else {
                    goveeConnectedView
                }
                
                if !configurationMessage.isEmpty {
                    Text(configurationMessage)
                        .font(.caption)
                        .foregroundColor(showingSuccess ? .green : .red)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }
    
    private var goveeNotConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your Govee API Key:")
                .font(.subheadline)
            
            HStack {
                SecureField("API Key", text: $goveeAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isConfiguring)
                    .focused($isAPIKeyFieldFocused)
                
                Button(action: {
                    showingAPIKeyInfo = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
                .help("How to get your Govee API Key")
            }
            
            HStack {
                Button("Configure API Key") {
                    configureGoveeAPIKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConfiguring)
                
                Button("Test API Key") {
                    testGoveeAPIKey()
                }
                .buttonStyle(.bordered)
                .disabled(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConfiguring)
                
                if isConfiguring {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }
    
    private var goveeConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API Key configured successfully")
                    .foregroundColor(.green)
            }
            
            Button("Remove API Key") {
                removeGoveeAPIKey()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var teamsIntegrationSection: some View {
        GroupBox("Microsoft Teams Integration") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Teams Status:")
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isTeamsConnected ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isTeamsConnected ? "Connected" : "Mock Data")
                            .font(.caption)
                    }
                }
                
                // Teams Status Indicator
                if let teamsStatus = viewModel.currentTeamsStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Presence:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 12) {
                            // Status indicator light matching the actual device color
                            Circle()
                                .fill(colorForStatus(teamsStatus.presence))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(teamsStatus.presence.displayName)
                                    .fontWeight(.medium)
                                
                                if let activity = teamsStatus.activity, !activity.isEmpty {
                                    Text(activity)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let lastUpdate = viewModel.lastStatusChange {
                                    Text("Updated \(timeAgoFormatter.string(for: lastUpdate) ?? "now")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(colorForStatus(teamsStatus.presence).opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                        Text("No Teams status available")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)
                }
                
                if !viewModel.isTeamsConnected {
                    teamsNotConnectedView
                } else {
                    teamsConnectedView
                }
                
                if viewModel.errorMessage?.contains("Client ID not configured") == true {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ Azure Configuration Required")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text("To use live Microsoft Teams data, you need to configure the Azure app registration. The current setup uses a placeholder Client ID.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Microsoft Teams integration provides real-time presence and calendar data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Teams Polling Interval Configuration (shown whether connected or not)
                teamsPollingIntervalView
            }
            .padding()
        }
    }
    
    private var teamsNotConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in to Microsoft Teams to get live presence data and calendar integration.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Sign in to Microsoft Teams") {
                authenticateWithTeams()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticatingTeams)
            
            if isAuthenticatingTeams {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Authenticating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var teamsConnectedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Microsoft Teams")
                    .foregroundColor(.green)
            }
            
            Text("Receiving live presence and calendar data")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Sign Out") {
                signOutFromTeams()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
    
    private var devicesSection: some View {
        GroupBox("Govee Devices") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Available Devices")
                        .fontWeight(.medium)
                    Spacer()
                    if viewModel.isGoveeConnected {
                        HStack {
                            Button("Refresh Devices") {
                                refreshGoveeDevices()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(viewModel.isRefreshingDevices)
                            
                            if viewModel.isRefreshingDevices {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                
                if viewModel.availableDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No devices discovered yet")
                            .foregroundColor(.secondary)
                        if viewModel.isGoveeConnected {
                            Text("Click 'Refresh Devices' to discover your Govee lights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Configure your Govee API key to discover devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if !viewModel.selectedDevices.isEmpty {
                            Text("Click the gear icon to assign devices to Teams status or Meeting tracker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                        }
                        
                        ForEach(viewModel.availableDevices, id: \.id) { device in
                            deviceRow(for: device)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isGoveeConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(viewModel.isGoveeConnected ? "Connected" : "Not Configured")
                .font(.caption)
        }
    }
    
    // Helper functions
    private func configureGoveeAPIKey() {
        isConfiguring = true
        configurationMessage = ""
        showingSuccess = false
        
        Task {
            do {
                try await viewModel.configureGoveeAPIKey(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
                
                await MainActor.run {
                    configurationMessage = "API Key configured successfully!"
                    showingSuccess = true
                    goveeAPIKey = "" // Clear the field for security
                    isConfiguring = false
                }
                
                // Auto-clear success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    configurationMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to configure API Key: \(error.localizedDescription)"
                    showingSuccess = false
                    isConfiguring = false
                }
                
                // Auto-clear error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    configurationMessage = ""
                }
            }
        }
    }
    
    private func testGoveeAPIKey() {
        isConfiguring = true
        configurationMessage = ""
        showingSuccess = false
        
        Task {
            await viewModel.testGoveeAPIKey(goveeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isConfiguring = false
            }
        }
    }
    
    private func removeGoveeAPIKey() {
        Task {
            do {
                try await viewModel.removeGoveeAPIKey()
                await MainActor.run {
                    configurationMessage = "API Key removed successfully"
                    showingSuccess = true
                }
                
                // Auto-clear message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    configurationMessage = ""
                }
                
            } catch {
                await MainActor.run {
                    configurationMessage = "Failed to remove API Key: \(error.localizedDescription)"
                    showingSuccess = false
                }
                
                // Auto-clear error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    configurationMessage = ""
                }
            }
        }
    }
    
    private func authenticateWithTeams() {
        isAuthenticatingTeams = true
        
        Task {
            await viewModel.authenticateTeams()
            
            await MainActor.run {
                isAuthenticatingTeams = false
            }
        }
    }
    
    private func signOutFromTeams() {
        Task {
            await viewModel.signOutFromTeams()
        }
    }
    
    private func refreshGoveeDevices() {
        Task {
            await viewModel.refreshGoveeDevices()
        }
    }
    
    private func colorForStatus(_ status: TeamsPresence) -> Color {
        let goveeColor = viewModel.colorMapping.colorForTeamsStatus(status)
        return goveeColor.color
    }
    
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    private func updatePollingInterval() {
        if let interval = Double(tempPollingInterval) {
            viewModel.updateTeamsPollingInterval(interval)
        }
    }
    
    
    private var teamsPollingIntervalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Polling Interval Configuration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Text("Check Teams status every:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: $tempPollingInterval)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .onSubmit {
                            updatePollingInterval()
                        }
                        .onAppear {
                            tempPollingInterval = String(Int(viewModel.teamsPollingInterval))
                        }
                    
                    Text("seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Update") {
                        updatePollingInterval()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(tempPollingInterval.isEmpty)
                }
                
                // API Usage Recommendations
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 API Usage Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text("• Minimum recommended: 15 seconds (Microsoft Graph rate limits)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("• For aggressive monitoring: 5-10 seconds (use sparingly)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("• Current: \(Int(viewModel.teamsPollingInterval)) seconds (\(apiUsageDescription))")
                            .font(.caption2)
                            .foregroundColor(apiUsageColor)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var apiUsageDescription: String {
        let interval = viewModel.teamsPollingInterval
        if interval >= 30 {
            return "Conservative"
        } else if interval >= 15 {
            return "Recommended"
        } else if interval >= 5 {
            return "Aggressive"
        } else {
            return "Very Aggressive"
        }
    }
    
    private var apiUsageColor: Color {
        let interval = viewModel.teamsPollingInterval
        if interval >= 15 {
            return .green
        } else if interval >= 5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Meeting Tracker Section
    private var meetingTrackerSection: some View {
        GroupBox("Meeting Countdown Tracker") {
            VStack(alignment: .leading, spacing: 12) {
                // Enable/Disable Toggle
                HStack {
                    Toggle("Enable Meeting Countdown", isOn: Binding(
                        get: { viewModel.meetingTracker.config.isEnabled },
                        set: { newValue in
                            var config = viewModel.meetingTracker.config
                            config.isEnabled = newValue
                            viewModel.updateMeetingTrackerConfig(config)
                        }
                    ))
                    .toggleStyle(.checkbox)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.meetingTracker.config.isEnabled ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.meetingTracker.config.isEnabled ? "Active" : "Disabled")
                            .font(.caption)
                    }
                }
                
                if viewModel.meetingTracker.config.isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        // Next Meeting Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next Meeting Info")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            // Try meeting tracker first, then fall back to upcoming meeting from calendar
                            let nextMeeting = viewModel.meetingTracker.currentState.nextMeeting ?? viewModel.upcomingMeeting
                            let _ = print("🖥️ SettingsView: =================== MEETING DEBUG ===================")
                            let _ = print("🖥️ SettingsView: Meeting Tracker enabled: \(viewModel.meetingTracker.config.isEnabled)")
                            let _ = print("🖥️ SettingsView: Meeting Tracker nextMeeting: \(viewModel.meetingTracker.currentState.nextMeeting?.subject ?? "none")")
                            let _ = print("🖥️ SettingsView: ViewModel upcomingMeeting: \(viewModel.upcomingMeeting?.subject ?? "none")")
                            let _ = print("🖥️ SettingsView: ViewModel upcomingMeeting showAs: \(viewModel.upcomingMeeting?.showAs.rawValue ?? "none")")
                            let _ = print("🖥️ SettingsView: ViewModel upcomingMeeting isUpcoming: \(viewModel.upcomingMeeting?.isUpcoming ?? false)")
                            let _ = print("🖥️ SettingsView: Using meeting: \(nextMeeting?.subject ?? "none")")
                            let _ = print("🖥️ SettingsView: ==================================================")
                            
                            if let nextMeeting = nextMeeting {
                                let _ = print("🖥️ SettingsView: Displaying next meeting: '\(nextMeeting.subject)' in \(nextMeeting.minutesUntilStart) minutes")
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    // Meeting title and status
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(viewModel.meetingTracker.currentState.isActive && nextMeeting.id == viewModel.meetingTracker.currentState.nextMeeting?.id ? .orange : .blue)
                                            .frame(width: 12, height: 12)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(nextMeeting.subject)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(2)
                                            
                                            HStack {
                                                if viewModel.meetingTracker.currentState.isActive && nextMeeting.id == viewModel.meetingTracker.currentState.nextMeeting?.id {
                                                    Text("Countdown Active • \(Int(viewModel.meetingTracker.currentState.progressPercentage * 100))% filled")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                } else {
                                                    Text("Upcoming")
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    // Meeting details
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Time info
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.secondary)
                                                .frame(width: 16)
                                            Text("Starts in \(nextMeeting.minutesUntilStart) minutes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // Start time
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.secondary)
                                                .frame(width: 16)
                                            Text(formatMeetingTime(nextMeeting.startTime))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // Duration
                                        HStack {
                                            Image(systemName: "timer")
                                                .foregroundColor(.secondary)
                                                .frame(width: 16)
                                            Text(formatDuration(nextMeeting.duration))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // Meeting type and status
                                        HStack {
                                            Image(systemName: "person.2")
                                                .foregroundColor(.secondary)
                                                .frame(width: 16)
                                            Text("\(nextMeeting.meetingType.displayName) • \(nextMeeting.showAs.displayName)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // Location if available
                                        if let location = nextMeeting.location, !location.isEmpty {
                                            HStack {
                                                Image(systemName: "location")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 16)
                                                Text(location)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        // Progress bar for active countdown (only for tracked meetings)
                                        if viewModel.meetingTracker.currentState.isActive && nextMeeting.id == viewModel.meetingTracker.currentState.nextMeeting?.id {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text("Countdown Progress")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(viewModel.meetingTracker.config.countdownDurationMinutes - viewModel.meetingTracker.currentState.minutesUntilMeeting) of \(viewModel.meetingTracker.config.countdownDurationMinutes) min")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                }
                                                
                                                ProgressView(value: viewModel.meetingTracker.currentState.progressPercentage)
                                                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                                    .scaleEffect(y: 0.5)
                                            }
                                        }
                                    }
                                    .padding(.leading, 4)
                                }
                                .padding(12)
                                .background((viewModel.meetingTracker.currentState.isActive && nextMeeting.id == viewModel.meetingTracker.currentState.nextMeeting?.id) ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                let _ = print("🖥️ SettingsView: No next meeting to display - both meetingTracker.nextMeeting and viewModel.upcomingMeeting are nil")
                                HStack {
                                    Image(systemName: "calendar.badge.minus")
                                        .foregroundColor(.secondary)
                                    Text("No upcoming meetings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                        
                        Divider()
                        
                        // Countdown Duration
                        HStack {
                            Text("Countdown Duration:")
                                .font(.subheadline)
                            
                            Stepper(value: Binding(
                                get: { viewModel.meetingTracker.config.countdownDurationMinutes },
                                set: { newValue in
                                    var config = viewModel.meetingTracker.config
                                    config.countdownDurationMinutes = newValue
                                    viewModel.updateMeetingTrackerConfig(config)
                                }
                            ), in: 5...60, step: 5) {
                                Text("\(viewModel.meetingTracker.config.countdownDurationMinutes) minutes")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Color Configuration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Light Colors")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 16) {
                                // Idle Color (Color 1)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Idle Color")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        ColorPicker("Idle", selection: Binding(
                                            get: { viewModel.meetingTracker.config.idleColor.color },
                                            set: { newColor in
                                                var config = viewModel.meetingTracker.config
                                                config.idleColor = GoveeColorValue(color: newColor)
                                                viewModel.updateMeetingTrackerConfig(config)
                                            }
                                        ))
                                        .labelsHidden()
                                        .frame(width: 40, height: 20)
                                        
                                        Text("RGB(\(viewModel.meetingTracker.config.idleColor.r), \(viewModel.meetingTracker.config.idleColor.g), \(viewModel.meetingTracker.config.idleColor.b))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Meeting Color (Color 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Meeting Color")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        ColorPicker("Meeting", selection: Binding(
                                            get: { viewModel.meetingTracker.config.meetingColor.color },
                                            set: { newColor in
                                                var config = viewModel.meetingTracker.config
                                                config.meetingColor = GoveeColorValue(color: newColor)
                                                viewModel.updateMeetingTrackerConfig(config)
                                            }
                                        ))
                                        .labelsHidden()
                                        .frame(width: 40, height: 20)
                                        
                                        Text("RGB(\(viewModel.meetingTracker.config.meetingColor.r), \(viewModel.meetingTracker.config.meetingColor.g), \(viewModel.meetingTracker.config.meetingColor.b))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Description
                        Text("Light strips will gradually fill with the meeting color as the countdown progresses. At the configured duration before a meeting, one end starts with the meeting color and spreads across the length until the meeting starts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } else {
                    Text("Enable this feature to show meeting countdowns on your Govee light strips with a progressive color fill effect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    // Helper function for device assignment colors
    private func colorForAssignment(_ assignment: DeviceAssignment) -> Color {
        switch assignment {
        case .teamsStatus:
            return .blue
        case .meetingTracker:
            return .orange
        case .both:
            return .purple
        }
    }
    
    // Extract device row to reduce complexity
    private func deviceRow(for device: GoveeDevice) -> some View {
        HStack {
            Button(action: {
                viewModel.toggleDeviceSelection(device)
            }) {
                deviceContent(for: device)
            }
            .buttonStyle(.plain)
            
            if viewModel.isDeviceSelected(device) {
                HStack(spacing: 8) {
                    // Assignment badge
                    deviceAssignmentBadge(for: device)
                    
                    // Function assignment dropdown
                    Menu {
                        ForEach(DeviceAssignment.allCases, id: \.self) { assignment in
                            Button(assignment.displayName) {
                                viewModel.setDeviceAssignment(device.id, assignment: assignment)
                            }
                        }
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                    }
                    .menuStyle(.borderlessButton)
                    
                    // Power toggle
                    Button(action: {
                        Task {
                            await viewModel.toggleDeviceActive(device)
                        }
                    }) {
                        Image(systemName: device.isActive ? "power.circle.fill" : "power.circle")
                            .foregroundColor(device.isActive ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func deviceContent(for device: GoveeDevice) -> some View {
        HStack {
            // Selection indicator
            Image(systemName: viewModel.isDeviceSelected(device) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(viewModel.isDeviceSelected(device) ? .blue : .secondary)
            
            // Connection status
            Circle()
                .fill(device.isConnected ? .green : .red)
                .frame(width: 6, height: 6)
            
            deviceInfo(for: device)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(viewModel.isDeviceSelected(device) ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private func deviceInfo(for device: GoveeDevice) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.deviceName)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            HStack {
                Text(device.sku)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show if device supports color
                if device.capabilities.contains(where: { $0.type.contains("color_setting") }) {
                    Image(systemName: "paintpalette.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func deviceAssignmentBadge(for device: GoveeDevice) -> some View {
        let assignment = viewModel.getDeviceAssignment(device.id)
        return Text(assignment.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForAssignment(assignment).opacity(0.2))
            .foregroundColor(colorForAssignment(assignment))
            .cornerRadius(4)
    }
    
    private func formatMeetingTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}


#Preview {
    SettingsView(viewModel: StatusLightViewModel())
        .frame(width: 500, height: 600)
}