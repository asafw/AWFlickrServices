// FlickrDemoApp.swift — Entry point for the FlickrDemoApp example.
// Run with: swift run FlickrDemoApp
// Requires macOS 13+ for SwiftUI @main in an SPM executable target.

import SwiftUI
import AppKit

@main
struct FlickrDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .onAppear {
                    // When launched via `swift run` the process is not automatically
                    // activated as the frontmost app, so keyboard events don't reach
                    // SwiftUI views. Force activation once the first view appears.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
    }
}
