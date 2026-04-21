// FlickrDemoApp.swift — Entry point for the FlickrDemoApp example.
// Run with: swift run FlickrDemoApp
// Requires macOS 13+ for SwiftUI @main in an SPM executable target.

import SwiftUI

@main
struct FlickrDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowStyle(.titleBar)
    }
}
