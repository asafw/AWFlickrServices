// FlickrDemoApp.swift — Entry point for the FlickrDemoApp example.
//
// macOS: swift run FlickrDemoApp  (from the package root)
// iOS:   open Examples/FlickrDemoApp-iOS/FlickrDemoApp-iOS.xcodeproj in Xcode,
//        set FLICKR_API_KEY in Product > Scheme > Edit Scheme > Run > Arguments,
//        then build and run on a simulator or device.

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

@main
struct FlickrDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 500)
                #endif
                .onAppear {
                    #if canImport(AppKit)
                    // swift run doesn't activate the process as frontmost app by
                    // default, so keyboard events don't reach SwiftUI views.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                }
        }
    }
}
