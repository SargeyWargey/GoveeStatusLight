//
//  ContentView.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StatusLightViewModel()
    @State private var showingSettings = false
    @State private var showingDebugger = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.accentColor)
                Text("StatusLight")
                    .font(.headline)
                Spacer()
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Status")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    connectionStatusIndicator
                }
                
                if let teamsStatus = viewModel.currentTeamsStatus {
                    HStack {
                        Image(systemName: teamsStatus.presence.systemImageName)
                            .foregroundColor(colorForStatus(teamsStatus.presence))
                        Text(teamsStatus.presence.displayName)
                        Spacer()
                        if let lastUpdate = viewModel.lastStatusChange {
                            Text(timeAgoFormatter.string(for: lastUpdate) ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No status available")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Upcoming Meeting Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming Meetings")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let meeting = viewModel.upcomingMeeting {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meeting.subject)
                            .fontWeight(.medium)
                        Text("in \(meeting.minutesUntilStart) minutes")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("No upcoming meetings")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Device Status Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Connected Devices")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if viewModel.selectedDevices.isEmpty {
                    Text("No devices configured")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.selectedDevices) { device in
                        HStack {
                            Circle()
                                .fill(device.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(device.deviceName)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
            
            Spacer()
            
            // Quick Actions
            HStack {
                Button("Refresh") {
                    Task {
                        await viewModel.refreshStatus()
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
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
        .frame(width: 300, height: 400)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .task {
            // Initial setup
            await viewModel.refreshStatus()
        }
    }
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isTeamsConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text("Teams")
                .font(.caption2)
            
            Circle()
                .fill(viewModel.isGoveeConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text("Govee")
                .font(.caption2)
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
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var goveeAPIKey: String = ""
    @State private var isConfiguring = false
    @State private var showingAPIKeyInfo = false
    @State private var configurationMessage: String = ""
    @State private var showingSuccess = false
    @State private var isAuthenticatingTeams = false
    
    private var settingsHeader: some View {
        Text("Settings")
            .font(.title)
            .padding(.bottom, 10)
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
        GroupBox("Connected Devices") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.selectedDevices.isEmpty {
                    Text("No devices discovered yet")
                        .foregroundColor(.secondary)
                    Text("Configure your Govee API key to discover devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.selectedDevices, id: \.id) { device in
                        HStack {
                            Circle()
                                .fill(device.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading) {
                                Text(device.deviceName)
                                    .fontWeight(.medium)
                                Text(device.sku)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            settingsHeader
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    goveeConfigurationSection
                    teamsIntegrationSection
                    devicesSection
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Close Button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500, height: 600)
        .alert("How to Get Your Govee API Key", isPresented: $showingAPIKeyInfo) {
            Button("OK") { }
        } message: {
            Text("1. Open the Govee Home App\\n2. Go to Profile → Settings\\n3. Select 'Apply for API Key'\\n4. Fill in your information\\n5. Check your email for the API key\\n\\nNote: You can only have one active API key at a time.")
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
                    configurationMessage = "Failed to configure API Key: \\(error.localizedDescription)"
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
                    configurationMessage = "Failed to remove API Key: \\(error.localizedDescription)"
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
}

#Preview {
    ContentView()
}
