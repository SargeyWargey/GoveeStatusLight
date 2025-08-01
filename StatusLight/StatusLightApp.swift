//
//  StatusLightApp.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import SwiftUI

@main
struct StatusLightApp: App {
    @StateObject private var sharedViewModel = StatusLightViewModel()
    
    var body: some Scene {
        // StatusLight MenuBarExtra - settings interface
        MenuBarExtra("StatusLight", systemImage: "lightbulb.fill") {
            SettingsView(viewModel: sharedViewModel)
                .frame(width: 500, height: 600)
        }
        .menuBarExtraStyle(.window)
    }
}
