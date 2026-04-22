//
//  FlickrOAuthProtocol.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import ObjectiveC
import AuthenticationServices

private var _webAuthSessionKey = "AWFlickrServices.webAuthSession"

public protocol FlickrOAuthProtocol {
    func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    )
}

extension FlickrOAuthProtocol {

    private var repository: FlickrAPIService { FlickrAPIService() }

    public func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    ) {
        repository.getRequestToken(
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: callbackUrlString
        ) { response in
            switch response {
            case .success(let requestTokenResponse):
                let urlString = FlickrEndpoints.authorizeEndpoint
                    + "?oauth_token=" + requestTokenResponse.oauth_token
                    + "&perms=write"
                guard let authURL = URL(string: urlString) else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
                }
                self.presentAuth(
                    context: context,
                    apiKey: apiKey,
                    apiSecret: apiSecret,
                    oauthTokenSecret: requestTokenResponse.oauth_token_secret,
                    callbackUrlString: callbackUrlString,
                    authURL: authURL,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func presentAuth(
        context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        oauthTokenSecret: String,
        callbackUrlString: String,
        authURL: URL,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    ) {
        let webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            // callbackURLScheme must be the URL scheme only (e.g. "myapp"),
            // not the full callback URL (e.g. "myapp://oauth").
            callbackURLScheme: URL(string: callbackUrlString)?.scheme ?? callbackUrlString
        ) { callbackURL, error in
            guard error == nil, let successURL = callbackURL else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            guard
                let components = URLComponents(string: successURL.absoluteString),
                let oauthToken = components.queryItems?.first(where: { $0.name == "oauth_token" })?.value,
                let oauthVerifier = components.queryItems?.first(where: { $0.name == "oauth_verifier" })?.value
            else {
                completion(.failure(FlickrAPIError.parsingError))
                return
            }
            self.repository.getAccessToken(
                apiKey: apiKey,
                apiSecret: apiSecret,
                oauthToken: oauthToken,
                oauthTokenSecret: oauthTokenSecret,
                oauthVerifier: oauthVerifier,
                completion: completion
            )
        }
        webAuthSession.presentationContextProvider = context
        objc_setAssociatedObject(context as AnyObject, &_webAuthSessionKey, webAuthSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        DispatchQueue.main.async {
            webAuthSession.start()
        }
    }

    // MARK: - Async/await overload

    /// Runs the full three-legged OAuth 1.0a flow and returns the access token response.
    public func performOAuthFlow(
        from context: ASWebAuthenticationPresentationContextProviding,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String
    ) async throws -> AccessTokenResponse {
        try await withCheckedThrowingContinuation { continuation in
            performOAuthFlow(
                from: context,
                apiKey: apiKey,
                apiSecret: apiSecret,
                callbackUrlString: callbackUrlString
            ) { continuation.resume(with: $0) }
        }
    }
}

