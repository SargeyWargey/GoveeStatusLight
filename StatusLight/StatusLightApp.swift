//
//  StatusLightApp.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import SwiftUI
import AppKit

@main
struct StatusLightApp: App {
    @StateObject private var sharedViewModel = StatusLightViewModel()
    
    var body: some Scene {
        // StatusLight MenuBarExtra - settings interface
        MenuBarExtra("StatusLight", systemImage: "lightbulb.fill") {
            MenuBarContentView(viewModel: sharedViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - MenuBar Content View with Native Blur
struct MenuBarContentView: View {
    @ObservedObject var viewModel: StatusLightViewModel
    
    var body: some View {
        SettingsView(viewModel: viewModel)
            .frame(width: 400, height: 180)
            .background(
                // Native macOS translucent material with proper blur
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    }
}

// MARK: - Native Visual Effect Blur for macOS
/**
 A SwiftUI wrapper around NSVisualEffectView for native macOS blur effects.
 
 Available Materials:
 - .menu: Perfect for dropdown menus and popups (default, most native for menubar)
 - .popover: Great for popovers and floating panels (more pronounced blur)
 - .sidebar: Ideal for sidebars and secondary content
 - .headerView: For header areas and toolbars
 - .sheet: Modal sheets and overlays
 - .windowBackground: Main window backgrounds
 - .hudWindow: HUD-style windows (minimal, floating appearance)
 - .fullScreenUI: Full-screen UI elements
 - .toolTip: Tooltip backgrounds
 - .contentBackground: Content area backgrounds
 
 Blending Modes:
 - .behindWindow: Blurs content behind the window (most common)
 - .withinWindow: Blurs content within the window
 */
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    init(material: NSVisualEffectView.Material = .menu, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
