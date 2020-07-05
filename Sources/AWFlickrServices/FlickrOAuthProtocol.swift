//
//  FlickrOAuthProtocol.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit
import AuthenticationServices

protocol FlickrOAuthProtocol {
    func performOAuthFlow(from viewController: UIViewController,
                          apiKey: String,
                          apiSecret: String,
                          callbackUrlString: String,
                          completion: @escaping (Result<AccessTokenResponse, Error>) -> Void)
}

extension FlickrOAuthProtocol {
    func performOAuthFlow(from viewController: UIViewController,
                          apiKey: String,
                          apiSecret: String,
                          callbackUrlString: String,
                          completion: @escaping (Result<AccessTokenResponse, Error>) -> Void) {
        FlickrAPIRepository().getRequestToken(apiKey: apiKey,
                                              apiSecret: apiSecret,
                                              callbackUrlString: callbackUrlString,
                                              completion: { response in
                                                switch response {
                                                case .success(let requestTokenResponse):
                                                    let urlString = FlickrEndpoints().authorizeEndpoint + "?oauth_token=" + requestTokenResponse.oauth_token + "&perms=write"
                                                    guard let authURL = URL(string: urlString) else {
                                                        completion(.failure(FlickrAPIError.parsingError))
                                                        return
                                                    }
                                                    self.presentAuth(viewController: viewController, apiKey: apiKey, apiSecret: apiSecret, oauthTokenSecret: requestTokenResponse.oauth_token_secret, callbackUrlString: callbackUrlString, authURL: authURL, completion: completion)
                                                case .failure(let error):
                                                    completion(.failure(error))
                                                }
        })
    }
    
    private func presentAuth(viewController: UIViewController,
                             apiKey: String,
                             apiSecret: String,
                             oauthTokenSecret: String,
                             callbackUrlString: String,
                             authURL: URL,
                             completion: @escaping (Result<AccessTokenResponse, Error>) -> Void) {
        let webAuthSession = ASWebAuthenticationSession.init(url: authURL, callbackURLScheme: callbackUrlString, completionHandler: { (callBack:URL?, error:Error?) in
            guard error == nil, let successURL = callBack else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            
            guard  let oauthToken = NSURLComponents(string: (successURL.absoluteString))?.queryItems?.filter({$0.name == "oauth_token"}).first?.value,
                let oauthVerifier = NSURLComponents(string: (successURL.absoluteString))?.queryItems?.filter({$0.name == "oauth_verifier"}).first?.value else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
            }
            self.getAccessToken(apiKey: apiKey,
                                apiSecret: apiSecret,
                                oauthToken: oauthToken,
                                oauthTokenSecret: oauthTokenSecret,
                                oauthVerifier: oauthVerifier,
                                completion: completion)
        })
        webAuthSession.presentationContextProvider = viewController as? ASWebAuthenticationPresentationContextProviding
        DispatchQueue.main.async {
            webAuthSession.start()
        }
    }
    
    private func getAccessToken(apiKey: String,
                                apiSecret: String,
                                oauthToken: String,
                                oauthTokenSecret: String,
                                oauthVerifier: String,
                                completion: @escaping (Result<AccessTokenResponse, Error>) -> Void) {
        FlickrAPIRepository().getAccessToken(apiKey: apiKey,
                                             apiSecret: apiSecret,
                                             oauthToken: oauthToken,
                                             oauthTokenSecret: oauthTokenSecret,
                                             oauthVerifier: oauthVerifier, completion: { response in
                                                switch response {
                                                case .success(let accessTokenResponse):
                                                    completion(.success(accessTokenResponse))
                                                case .failure(let error):
                                                    completion(.failure(error))
                                                }
        })
    }
}



