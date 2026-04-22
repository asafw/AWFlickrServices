//
//  FlickrOAuthProtocol.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import ObjectiveC
import AuthenticationServices

private var _webAuthSessionKey = "AWFlickrServices.webAuthSession"
// Note: the pointer to this file-scope variable is used as the associated-object key,
// not the string value. An ObjC associated-object key must be a stable pointer;
// a pointer to a global var satisfies this requirement without any extra allocation.

/// Provides three-legged OAuth 1.0a authentication with the Flickr API.
///
/// Conform your type to this protocol to gain the full OAuth flow via the
/// default implementation in the protocol extension.
public protocol FlickrOAuthProtocol {

    /// The `URLSession` used by the default OAuth flow implementation.
    ///
    /// Override to inject a custom session for testing or custom configuration.
    ///
    /// ### Design rationale
    /// The internal `FlickrAPIService` type holds the actual HTTP logic. Exposing
    /// `URLSession` here keeps the public API surface free of internal details
    /// while still allowing full session control (e.g. custom `URLProtocol`
    /// subclasses for tests) without overriding the entire OAuth flow.
    /// The default implementation returns `URLSession.shared`.
    var urlSession: URLSession { get }

    /// Runs the full three-legged OAuth 1.0a flow and returns the access token response.
    func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String
    ) async throws -> AccessTokenResponse
}

public extension FlickrOAuthProtocol {

    var urlSession: URLSession { .shared }

    private var service: FlickrAPIService { FlickrAPIService(session: urlSession) }

    func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String
    ) async throws -> AccessTokenResponse {
        let requestToken = try await service.getRequestToken(
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: callbackUrlString
        )
        let urlString = FlickrEndpoints.authorizeEndpoint
            + "?oauth_token=" + requestToken.oauth_token
            + "&perms=write"
        guard let authURL = URL(string: urlString) else {
            throw FlickrAPIError.parsingError
        }
        return try await presentAuth(
            context: context,
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthTokenSecret: requestToken.oauth_token_secret,
            callbackUrlString: callbackUrlString,
            authURL: authURL
        )
    }

    private func presentAuth(
        context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        oauthTokenSecret: String,
        callbackUrlString: String,
        authURL: URL
    ) async throws -> AccessTokenResponse {
        // Bridge ASWebAuthenticationSession's completion-handler API into
        // Swift structured concurrency using a checked throwing continuation.
        // The continuation is resumed exactly once: either with the parsed
        // (oauthToken, oauthVerifier) tuple on success, or by throwing on
        // user cancellation (ASWebAuthenticationSessionError.canceledLogin)
        // or a malformed callback URL (FlickrAPIError.parsingError).
        let (oauthToken, oauthVerifier): (String, String) = try await withCheckedThrowingContinuation { continuation in
            let webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                // callbackURLScheme must be the URL scheme only (e.g. "myapp"),
                // not the full callback URL string (e.g. "myapp://oauth").
                // Passing the full URL broke scheme matching on some OS versions.
                callbackURLScheme: URL(string: callbackUrlString)?.scheme ?? callbackUrlString
            ) { callbackURL, error in
                guard error == nil, let successURL = callbackURL else {
                    continuation.resume(throwing: error ?? FlickrAPIError.networkError)
                    return
                }
                guard
                    let components = URLComponents(string: successURL.absoluteString),
                    let token = components.queryItems?.first(where: { $0.name == "oauth_token" })?.value,
                    let verifier = components.queryItems?.first(where: { $0.name == "oauth_verifier" })?.value
                else {
                    continuation.resume(throwing: FlickrAPIError.parsingError)
                    return
                }
                continuation.resume(returning: (token, verifier))
            }
            webAuthSession.presentationContextProvider = context
            // ASWebAuthenticationSession must remain alive for the entire browser
            // redirect flow. The continuation closure does not hold a strong reference
            // to the session (it only captures `continuation`), so the session would
            // be released immediately after this block returns — dismissing the browser
            // sheet before the user can authorise the app.
            //
            // Associating the session with `context` (the window scene / NSWindow)
            // keeps it strongly retained for at least as long as the UI is visible,
            // which is the correct lifetime. .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            // provides strong ARC ownership without the overhead of atomic locking.
            objc_setAssociatedObject(
                context as AnyObject, &_webAuthSessionKey, webAuthSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            // ASWebAuthenticationSession.start() must be called from the main thread.
            // The surrounding async function may execute on any executor, so dispatch
            // explicitly rather than assuming the current thread is main.
            DispatchQueue.main.async { webAuthSession.start() }
        }
        return try await service.getAccessToken(
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthToken: oauthToken,
            oauthTokenSecret: oauthTokenSecret,
            oauthVerifier: oauthVerifier
        )
    }
}

