//
//  FlickrOAuthUtilities.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation
import CommonCrypto

// Utility functions for generating signed OAuth 1.0a URLs.

func generateRequestTokenURL(apiKey: String, apiSecret: String, callbackUrlString: String) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.requestTokenEndpoint,
        parameters: getParameters(apiKey: apiKey, oauthCallback: callbackUrlString)
    )
    return URL(string: urlString)
}

func generateAccessTokenURL(
    apiKey: String,
    apiSecret: String,
    oauthToken: String,
    oauthTokenSecret: String,
    oauthVerifier: String
) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.accessTokenEndpoint,
        parameters: getParameters(apiKey: apiKey, oauthToken: oauthToken, oauthVerifier: oauthVerifier),
        oauthTokenSecret: oauthTokenSecret
    )
    return URL(string: urlString)
}

func generateFaveURL(
    apiKey: String,
    apiSecret: String,
    oauthToken: String,
    oauthTokenSecret: String,
    photoId: String
) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.hostURL,
        parameters: getParameters(
            apiKey: apiKey,
            method: FlickrEndpoints.faveEndpoint,
            oauthToken: oauthToken,
            photoId: photoId
        ),
        oauthTokenSecret: oauthTokenSecret,
        httpMethod: "POST"
    )
    return URL(string: urlString)
}

func generateUnfaveURL(
    apiKey: String,
    apiSecret: String,
    oauthToken: String,
    oauthTokenSecret: String,
    photoId: String
) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.hostURL,
        parameters: getParameters(
            apiKey: apiKey,
            method: FlickrEndpoints.unFaveEndpoint,
            oauthToken: oauthToken,
            photoId: photoId
        ),
        oauthTokenSecret: oauthTokenSecret,
        httpMethod: "POST"
    )
    return URL(string: urlString)
}

func generateCommentURL(
    apiKey: String,
    apiSecret: String,
    oauthToken: String,
    oauthTokenSecret: String,
    photoId: String,
    commentText: String
) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.hostURL,
        parameters: getParameters(
            apiKey: apiKey,
            method: FlickrEndpoints.commentEndpoint,
            oauthToken: oauthToken,
            photoId: photoId,
            commentText: commentText
        ),
        oauthTokenSecret: oauthTokenSecret,
        httpMethod: "POST"
    )
    return URL(string: urlString)
}

private func encryptedURLWithBaseURL(
    apiSecret: String,
    url: String,
    parameters: [String: String],
    oauthTokenSecret: String? = nil,
    httpMethod: String = "GET"
) -> String {
    var parameters = parameters
    let urlStringBeforeSignature = sortedURLString(url: url, parameters: parameters, urlEscape: true)
    let secretKey = "\(apiSecret)&\(oauthTokenSecret ?? "")"
    let signatureString = "\(httpMethod)&\(urlStringBeforeSignature)"
    let signature = hmacsha1EncryptedString(string: signatureString, key: secretKey)
    parameters["oauth_signature"] = signature
    return sortedURLString(url: url, parameters: parameters, urlEscape: false)
}

private func getParameters(
    apiKey: String,
    method: String? = nil,
    oauthToken: String? = nil,
    oauthVerifier: String? = nil,
    oauthCallback: String? = nil,
    photoId: String? = nil,
    commentText: String? = nil
) -> [String: String] {
    let timestamp = String(Int(floor(Date().timeIntervalSince1970)))
    let nonce = UUID().uuidString
    var parameters: [String: String] = [
        "oauth_nonce": nonce,
        "oauth_timestamp": timestamp,
        "oauth_consumer_key": apiKey,
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_version": "1.0",
    ]
    if let oauthCallback { parameters["oauth_callback"] = oauthCallback }
    if let oauthToken { parameters["oauth_token"] = oauthToken }
    if let oauthVerifier { parameters["oauth_verifier"] = oauthVerifier }
    if let method {
        parameters["method"] = method
        parameters["nojsoncallback"] = "1"
        parameters["format"] = "json"
    }
    if let photoId { parameters["photo_id"] = photoId }
    if let commentText { parameters["comment_text"] = commentText }
    return parameters
}

private func sortedURLString(url: String, parameters: [String: String], urlEscape: Bool) -> String {
    let keys = parameters.keys.sorted()
    let pairs = keys.compactMap { key -> String? in
        guard let value = parameters[key] else { return nil }
        return "\(key)=\(oauthEncodedString(string: value))"
    }
    var urlString = urlEscape ? urlEncodedString(string: url) : url
    urlString += urlEscape ? "&" : "?"
    let args = pairs.joined(separator: "&")
    urlString += urlEscape ? urlEncodedString(string: args) : args
    return urlString
}

private func urlEncodedString(string: String) -> String {
    let allowed = CharacterSet(charactersIn: "% /'\"?=&+<>;:!").inverted
    return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}

private func oauthEncodedString(string: String) -> String {
    let allowed = CharacterSet(charactersIn: "%:/?#[]@!$&'()*+,;=").inverted
    return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
}

private func hmacsha1EncryptedString(string: String, key: String) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key, key.utf8.count, string, string.utf8.count, &digest)
    return Data(digest).base64EncodedString()
}

