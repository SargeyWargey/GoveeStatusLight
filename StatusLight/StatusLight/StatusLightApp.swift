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
        // StatusLight MenuBarExtra - primary interface
        MenuBarExtra("StatusLight", systemImage: "lightbulb.fill") {
            ContentView()
                .environmentObject(sharedViewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
