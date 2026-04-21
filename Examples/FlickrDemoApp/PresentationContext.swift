// PresentationContext.swift — Cross-platform ASWebAuthenticationPresentationContextProviding.
// Provides the anchor window needed to present the Flickr OAuth web sheet.

import AuthenticationServices

#if canImport(AppKit)
import AppKit

/// On macOS, returns the current key window as the presentation anchor.
final class PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSWindow()
    }
}

#elseif canImport(UIKit)
import UIKit

/// On iOS, returns the key window from the active UIWindowScene.
final class PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow }
            .first
            ?? UIWindow()
    }
}
#endif
