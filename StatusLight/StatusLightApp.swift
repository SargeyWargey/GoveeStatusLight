//
//  StatusLightApp.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/30/25.
//

import SwiftUI

@main
struct StatusLightApp: App {
    var body: some Scene {
        // StatusLight MenuBarExtra - primary interface
        MenuBarExtra("StatusLight", systemImage: "lightbulb.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
