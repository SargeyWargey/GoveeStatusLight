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

// MARK: - Settings View Placeholder
struct SettingsView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .padding()
            
            Text("Settings interface coming soon...")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
