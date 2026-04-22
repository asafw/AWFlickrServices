//
//  FlickrOAuthProtocol.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import ObjectiveC
import AuthenticationServices

private var _webAuthSessionKey = "AWFlickrServices.webAuthSession"

/// Provides three-legged OAuth 1.0a authentication with the Flickr API.
///
/// Conform your type to this protocol to gain the full OAuth flow via the
/// default implementation in the protocol extension.
public protocol FlickrOAuthProtocol {

    /// Runs the full three-legged OAuth 1.0a flow and returns the access token response.
    func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String
    ) async throws -> AccessTokenResponse
}

extension FlickrOAuthProtocol {

    private var service: FlickrAPIService { FlickrAPIService() }

    public func performOAuthFlow(
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
        // ASWebAuthenticationSession uses a completion handler; bridge it here.
        let (oauthToken, oauthVerifier): (String, String) = try await withCheckedThrowingContinuation { continuation in
            let webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                // callbackURLScheme must be the URL scheme only (e.g. "myapp"),
                // not the full callback URL (e.g. "myapp://oauth").
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
            objc_setAssociatedObject(
                context as AnyObject, &_webAuthSessionKey, webAuthSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
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

