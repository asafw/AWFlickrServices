// PlatformImage.swift — Cross-platform image type alias for FlickrDemoApp.
// Allows PhotoGridView and PhotoDetailView to compile on both macOS and iOS
// without conditional compilation at every call site.

import SwiftUI

#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
extension Image {
    init(platformImage image: PlatformImage) { self.init(nsImage: image) }
}
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
extension Image {
    init(platformImage image: PlatformImage) { self.init(uiImage: image) }
}
#endif
