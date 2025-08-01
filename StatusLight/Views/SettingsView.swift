//
//  SettingsView.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/31/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    @State private var goveeAPIKey: String = ""
    @State private var isConfiguring = false
    @State private var showingAPIKeyInfo = false
    @State private var configurationMessage: String = ""
    @State private var showingSuccess = false
    @FocusState private var isAPIKeyFieldFocused: Bool
    @State private var isAuthenticatingTeams = false
    
    private var settingsHeader: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.accentColor)
                .font(.title2)
            Text("StatusLight Settings")
                .font(.title)
                .fontWeight(.medium)
            Spacer()
            
            // Quick Actions
            HStack(spacing: 8) {
                Button("Refresh") {
                    Task {
                        await viewModel.refreshGoveeDevices()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.bottom, 10)
    }
    
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
                
                // Current Light Color Preview
                if let currentColor = viewModel.currentLightColor {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Light")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Circle()
                            .fill(Color(red: Double(currentColor.r)/255, green: Double(currentColor.g)/255, blue: Double(currentColor.b)/255))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding()
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
                                HStack {
                                    Image(systemName: teamsStatus.presence.systemImageName)
                                        .foregroundColor(colorForStatus(teamsStatus.presence))
                                    Text(teamsStatus.presence.displayName)
                                        .fontWeight(.medium)
                                }
                                
                                if let activity = teamsStatus.activity, !activity.isEmpty {
                                    Text(activity)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let lastUpdate = viewModel.lastStatusChange {
                                    Text("Updated \(timeAgoFormatter.string(for: lastUpdate) ?? "")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Show this matches your lights
                            if !viewModel.selectedDevices.isEmpty {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Light Color")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Circle()
                                        .fill(colorForStatus(teamsStatus.presence))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                                        )
                                }
                            }
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
                            Text("Selected devices will sync with your Teams status")
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
                                        // Selection indicator
                                        Image(systemName: viewModel.isDeviceSelected(device) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.isDeviceSelected(device) ? .blue : .secondary)
                                        
                                        // Connection status
                                        Circle()
                                            .fill(device.isConnected ? .green : .red)
                                            .frame(width: 6, height: 6)
                                        
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
                                        
                                        Spacer()
                                        
                                        if viewModel.isDeviceSelected(device) {
                                            Text("Teams Sync")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(viewModel.isDeviceSelected(device) ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            settingsHeader
            
            statusOverview
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    goveeConfigurationSection
                    teamsIntegrationSection
                    devicesSection
                }
                .padding(.horizontal)
            }
            
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
        .padding()
        .task {
            // Initial setup when settings view appears
            await viewModel.refreshGoveeDevices()
        }
        .alert("How to Get Your Govee API Key", isPresented: $showingAPIKeyInfo) {
            Button("OK") { }
        } message: {
            Text("1. Open the Govee Home App\n2. Go to Profile → Settings\n3. Select 'Apply for API Key'\n4. Fill in your information\n5. Check your email for the API key\n\nNote: You can only have one active API key at a time.")
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
    
    // MARK: - Helper Functions for SettingsView
    private func colorForStatus(_ status: TeamsPresence) -> Color {
        let goveeColor = viewModel.colorMapping.colorForTeamsStatus(status)
        return goveeColor.color
    }
    
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

#Preview {
    SettingsView(viewModel: StatusLightViewModel())
        .frame(width: 500, height: 600)
}