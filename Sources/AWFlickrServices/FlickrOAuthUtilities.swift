//
//  FlickrOAuthUtilities.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation
import CommonCrypto

//Utility methods for generating URLs for Oauth & Oauth-protected API calls

func generateRequestTokenURL(apiKey: String, apiSecret: String, callbackUrlString: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().requestTokenEndpoint,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      oauthCallback: callbackUrlString))
    return URL(string: urlString)
}

func generateAccessTokenURL(apiKey: String, apiSecret: String, oauthToken: String, oauthTokenSecret: String, oauthVerifier: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().accessTokenEndpoint,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      oauthToken: oauthToken,
                                                                      oauthVerifier: oauthVerifier),
                                            oauthTokenSecret: oauthTokenSecret)
    return URL(string: urlString)
}

func generateFaveURL(apiKey: String, apiSecret: String, oauthToken: String, oauthTokenSecret: String, photoId: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().hostURL,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      method: FlickrEndpoints().faveEndpoint,
                                                                      oauthToken: oauthToken,
                                                                      photoId: photoId),
                                            oauthTokenSecret: oauthTokenSecret,
                                            httpMethod: "POST")
    return URL(string: urlString)
}

func generateUnfaveURL(apiKey: String, apiSecret: String, oauthToken: String, oauthTokenSecret: String, photoId: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().hostURL,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      method: FlickrEndpoints().unFaveEndpoint,
                                                                      oauthToken: oauthToken,
                                                                      photoId: photoId),
                                            oauthTokenSecret: oauthTokenSecret,
                                            httpMethod: "POST")
    return URL(string: urlString)
}

func generateCommentURL(apiKey: String, apiSecret: String, oauthToken: String, oauthTokenSecret: String, photoId: String, commentText: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().hostURL,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      method: FlickrEndpoints().commentEndpoint,
                                                                      oauthToken: oauthToken,
                                                                      photoId: photoId,
                                                                      commentText: commentText),
                                            oauthTokenSecret: oauthTokenSecret,
                                            httpMethod: "POST")
    return URL(string: urlString)
}

func generatePermsURL(apiKey: String, apiSecret: String, oauthToken: String, oauthTokenSecret: String, photoId: String) -> URL? {
    let urlString = encriptedURLWithBaseURL(apiSecret: apiSecret,
                                            url: FlickrEndpoints().hostURL,
                                            parameters: getParameters(apiKey: apiKey,
                                                                      method: FlickrEndpoints().permsEndpoint,
                                                                      oauthToken: oauthToken,
                                                                      photoId: photoId),
                                            oauthTokenSecret: oauthTokenSecret)
    return URL(string: urlString)
}

private func encriptedURLWithBaseURL(apiSecret: String,
                                     url: String,
                                     parameters: [String : String],
                                     oauthTokenSecret: String? = nil,
                                     httpMethod: String = "GET") -> String {
    var parameters = parameters
    let urlStringBeforeSignature = sortedURLString(url: url, parameters: parameters, urlEscape: true)
    let secretKey = "\(apiSecret)&\(oauthTokenSecret ?? "")"
    let signatureString = "\(httpMethod)&\(urlStringBeforeSignature)"
    let signature = hmacsha1EncryptedString(string: signatureString, key: secretKey)
    
    parameters["oauth_signature"] = signature
    
    return sortedURLString(url: url, parameters: parameters, urlEscape: false)
}

private func getParameters(apiKey: String,
                           method: String? = nil,
                           oauthToken: String? = nil,
                           oauthVerifier: String? = nil,
                           oauthCallback: String? = nil,
                           photoId: String? = nil,
                           commentText: String? = nil) -> [String : String] {
    let timestamp = (floor(NSDate().timeIntervalSince1970) as NSNumber).stringValue
    let nonce = NSUUID().uuidString
    let signatureMethod = "HMAC-SHA1"
    let version = "1.0"
    var parameters =  ["oauth_nonce" : nonce,
                       "oauth_timestamp" : timestamp,
                       "oauth_consumer_key" : apiKey,
                       "oauth_signature_method" : signatureMethod,
                       "oauth_version" : version ]
    
    if let oauthCallback = oauthCallback {
        parameters["oauth_callback"] = oauthCallback
    }
    if let oauthToken = oauthToken {
        parameters["oauth_token"] = oauthToken
    }
    if let oauthVerifier = oauthVerifier {
        parameters["oauth_verifier"] = oauthVerifier
    }
    if let method = method {
        parameters["method"] = method
        parameters["nojsoncallback"] = "1"
        parameters["format"] = "json"
    }
    if let photoId = photoId {
        parameters["photo_id"] = photoId
    }
    if let commentText = commentText {
        parameters["comment_text"] = commentText
    }
    return parameters
}

private func sortedURLString(url: String, parameters: [String : String], urlEscape: Bool) -> String {
    var pairs = [String]()
    let keys = Array(parameters.keys).sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } )
    keys.forEach { key in
        if let value = parameters[key] {
            let escapedValue = oauthEncodedString(string: value)
            pairs.append("\(key)=\(escapedValue)")
        }
    }
    
    var urlString = url
    if urlEscape { urlString = urlEncodedString(string: urlString) }
    urlString += (urlEscape ? "&" : "?")
    
    var args = pairs.joined(separator: "&")
    if urlEscape { args = urlEncodedString(string: args) }
    urlString += args
    
    return urlString
}

private func urlEncodedString(string: String) -> String {
    let ignoredCharacters = NSCharacterSet(charactersIn: "% /'\"?=&+<>;:!").inverted
    return string.addingPercentEncoding(withAllowedCharacters: ignoredCharacters) ?? ""
}

private func oauthEncodedString(string: String) -> String {
    let ignoredCharacters = NSCharacterSet(charactersIn: "%:/?#[]@!$&'()*+,;=").inverted
    return string.addingPercentEncoding(withAllowedCharacters: ignoredCharacters) ?? ""
}

private func hmacsha1EncryptedString(string: String, key: String) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key, key.count, string, string.count, &digest)
    let data = Data(digest)
    return data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
}

