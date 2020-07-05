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

struct AccessTokenResponse: Decodable {
    let fullname: String
    let oauth_token: String
    let oauth_token_secret: String
    let user_nsid: String
    let username: String
}
