//
//  MenuBarDebugger.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import SwiftUI
import AppKit

struct MenuBarDebugger: View {
    @State private var debugInfo: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu Bar Debug Info")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(debugInfo, id: \.self) { info in
                        Text(info)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(height: 200)
            
            HStack {
                Button("Refresh Debug") {
                    updateDebugInfo()
                }
                
                Button("Try Force Menu Bar") {
                    forceMenuBarRefresh()
                }
                
                Button("Copy Debug Info") {
                    copyDebugInfo()
                }
            }
        }
        .padding()
        .onAppear {
            updateDebugInfo()
        }
    }
    
    private func updateDebugInfo() {
        debugInfo.removeAll()
        
        // Basic app info
        debugInfo.append("=== APP STATUS ===")
        debugInfo.append("Activation Policy: \(NSApp.activationPolicy().rawValue)")
        debugInfo.append("Is Active: \(NSApp.isActive)")
        debugInfo.append("Is Hidden: \(NSApp.isHidden)")
        debugInfo.append("Windows Count: \(NSApp.windows.count)")
        
        // Menu bar info
        debugInfo.append("\n=== MENU BAR STATUS ===")
        debugInfo.append("Menu Bar Visible: \(NSMenu.menuBarVisible())")
        debugInfo.append("Main Menu Items: \(NSApp.mainMenu?.items.count ?? 0)")
        
        // Screen info
        debugInfo.append("\n=== SCREEN INFO ===")
        if let screen = NSScreen.main {
            debugInfo.append("Screen Size: \(Int(screen.frame.width))x\(Int(screen.frame.height))")
            debugInfo.append("Menu Bar Height: \(Int(screen.frame.height - screen.visibleFrame.height))")
        }
        
        // System info
        debugInfo.append("\n=== SYSTEM INFO ===")
        debugInfo.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        debugInfo.append("App Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Menu bar apps detection
        debugInfo.append("\n=== MENU BAR APPS ===")
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        let menuApps = runningApps.filter { app in
            app.activationPolicy == .accessory || app.activationPolicy == .prohibited
        }
        debugInfo.append("Menu Bar Apps Count: \(menuApps.count)")
        for app in menuApps.prefix(10) {
            if let name = app.localizedName {
                debugInfo.append("  - \(name)")
            }
        }
        
        // Check for common issues
        debugInfo.append("\n=== DIAGNOSTICS ===")
        if menuApps.count > 20 {
            debugInfo.append("⚠️ Many menu bar apps - might be hidden")
        }
        if let screen = NSScreen.main, screen.frame.width < 1400 {
            debugInfo.append("⚠️ Small screen - menu items might overflow")
        }
        
        // Print to console as well
        for info in debugInfo {
            print(info)
        }
    }
    
    private func forceMenuBarRefresh() {
        debugInfo.append("\n=== FORCING REFRESH ===")
        
        // Try multiple activation policies
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.setActivationPolicy(.regular)
                self.updateDebugInfo()
            }
        }
    }
    
    private func copyDebugInfo() {
        let fullInfo = debugInfo.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullInfo, forType: .string)
    }
}

#Preview {
    MenuBarDebugger()
}