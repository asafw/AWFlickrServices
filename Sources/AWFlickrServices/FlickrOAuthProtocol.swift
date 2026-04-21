//
//  FlickrOAuthProtocol.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit
import AuthenticationServices

public protocol FlickrOAuthProtocol {
    func performOAuthFlow(
        from viewController: UIViewController,
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    )
}

extension FlickrOAuthProtocol {

    private var repository: FlickrAPIRepository { FlickrAPIRepository() }

    public func performOAuthFlow(
        from viewController: UIViewController,
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
                    viewController: viewController,
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
        viewController: UIViewController,
        apiKey: String,
        apiSecret: String,
        oauthTokenSecret: String,
        callbackUrlString: String,
        authURL: URL,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    ) {
        let webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackUrlString
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
            self.getAccessToken(
                apiKey: apiKey,
                apiSecret: apiSecret,
                oauthToken: oauthToken,
                oauthTokenSecret: oauthTokenSecret,
                oauthVerifier: oauthVerifier,
                completion: completion
            )
        }
        webAuthSession.presentationContextProvider = viewController as? ASWebAuthenticationPresentationContextProviding
        DispatchQueue.main.async {
            webAuthSession.start()
        }
    }

    private func getAccessToken(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        oauthVerifier: String,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    ) {
        repository.getAccessToken(
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthToken: oauthToken,
            oauthTokenSecret: oauthTokenSecret,
            oauthVerifier: oauthVerifier,
            completion: completion
        )
    }
}

