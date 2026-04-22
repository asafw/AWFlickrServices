//
//  FlickrOAuthModels.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

// Internal model for step 1 of the OAuth 1.0a flow (request-token response).
//
// Flickr does NOT return JSON here — the response body is a URL-encoded form string,
// e.g. "oauth_token=abc&oauth_token_secret=xyz&oauth_callback_confirmed=true".
// `Decodable` would be useless, so the struct is plain and fields are populated
// manually via key-value splitting in FlickrAPIService.getRequestToken.
struct RequestTokenResponse {
    let oauth_callback_confirmed: String
    let oauth_token: String
    let oauth_token_secret: String
}

/// The access token returned after a successful OAuth 1.0a authorisation flow.
///
/// Flickr returns the access token as a URL-encoded form string (the same format as
/// the request-token response), not as JSON. `Decodable` is therefore not implemented
/// — fields are populated by splitting on `&` and `=` in `FlickrAPIService.getAccessToken`.
/// The first `=` delimiter is located with `range(of:)` rather than `components(separatedBy:)`
/// to handle values (such as `oauth_token_secret`) that may contain Base64 padding `=` signs.
public struct AccessTokenResponse: Sendable {
    public let fullname: String
    public let oauth_token: String
    public let oauth_token_secret: String
    public let user_nsid: String
    public let username: String
}
