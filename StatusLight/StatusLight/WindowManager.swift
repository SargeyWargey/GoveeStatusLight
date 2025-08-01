//
//  WindowManager.swift
//  StatusLight
//
//  Created by Joshua Sargent on 7/31/25.
//

import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    private var settingsWindow: NSWindow?
    private var windowDelegate: WindowDelegate?
    
    func openSettingsWindow(with viewModel: StatusLightViewModel) {
        if let existingWindow = settingsWindow {
            // Bring existing window to front
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create new window with standard macOS controls
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "StatusLight Settings"
        window.center()
        window.minSize = NSSize(width: 450, height: 500)
        window.maxSize = NSSize(width: 600, height: 800)
        
        // Create window delegate to handle cleanup
        windowDelegate = WindowDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.windowDelegate = nil
        }
        window.delegate = windowDelegate
        
        // Set up SwiftUI content
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
        window.contentView?.wantsLayer = true
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
    
    func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
        windowDelegate = nil
    }
}

// Window delegate to handle cleanup
class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}