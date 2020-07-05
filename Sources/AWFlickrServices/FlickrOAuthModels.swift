//
//  FlickrOAuthModels.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

struct RequestTokenResponse: Decodable {
    let oauth_callback_confirmed: String
    let oauth_token: String
    let oauth_token_secret: String
}

public struct AccessTokenResponse: Decodable {
    public let fullname: String
    public let oauth_token: String
    public let oauth_token_secret: String
    public let user_nsid: String
    public let username: String
}
