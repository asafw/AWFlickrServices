//
//  FlickrOAuthUtilities.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation
import CommonCrypto

// MARK: - Signed URL generators
//
// These are the entry points called by FlickrAPIService. Each delegates to
// encryptedURLWithBaseURL, which owns the full OAuth 1.0a signing algorithm.
// Splitting per-endpoint keeps FlickrAPIService call sites short and makes the
// differing per-endpoint parameters (e.g. commentText only for comments) explicit.

/// Builds a signed OAuth 1.0a request-token URL (step 1 of the three-legged flow).
///
/// The request-token step exchanges your API key and callback URL for a short-lived
/// `oauth_token` / `oauth_token_secret` pair. These are used in step 2 to construct
/// the Flickr authorisation URL the user opens in a browser sheet.
///
/// **Signing key at this step:** `"apiSecret&"` — the token secret portion is empty
/// because no access token has been issued yet (OAuth 1.0a §3.4.2).
///
/// - Returns: `nil` only if `FlickrEndpoints.requestTokenEndpoint` is a malformed URL,
///   which cannot occur because it is a compile-time constant string.
func generateRequestTokenURL(apiKey: String, apiSecret: String, callbackUrlString: String) -> URL? {
    let urlString = encryptedURLWithBaseURL(
        apiSecret: apiSecret,
        url: FlickrEndpoints.requestTokenEndpoint,
        parameters: getParameters(apiKey: apiKey, oauthCallback: callbackUrlString)
    )
    return URL(string: urlString)
}

/// Builds a signed OAuth 1.0a access-token URL (step 3 of the three-legged flow).
///
/// After the user authorises the app on flickr.com, Flickr redirects back to the
/// callback URL with `oauth_token` and `oauth_verifier` query parameters. This
/// function exchanges those values — plus the request-token secret from step 1 —
/// for permanent `oauth_token` / `oauth_token_secret` credentials.
///
/// **Signing key at this step:** `"apiSecret&requestTokenSecret"` — the request-token
/// secret is now known and required (OAuth 1.0a §3.4.2).
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

/// Builds a signed OAuth 1.0a URL for `flickr.favorites.add` (HTTP POST).
///
/// Write operations require a fully signed OAuth request with the user's permanent
/// access-token credentials. Including `method`, `format`, and `nojsoncallback`
/// causes Flickr to return a JSON envelope so `checkFlickrError` can detect
/// `stat:fail` responses even when the HTTP status is 200.
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

/// Builds a signed OAuth 1.0a URL for `flickr.favorites.remove` (HTTP POST).
/// See `generateFaveURL` for the OAuth signing rationale.
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

/// Builds a signed OAuth 1.0a URL for `flickr.photos.comments.addComment` (HTTP POST).
/// See `generateFaveURL` for the OAuth signing rationale.
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

/// Core OAuth 1.0a signing function. Produces a complete, signed URL ready to
/// send as a Flickr API request.
///
/// ### Signing algorithm (OAuth 1.0a §3.4)
///
/// **1. Collect parameters.**
/// The caller supplies all OAuth + API parameters *except* `oauth_signature`
/// (which is what this function computes).
///
/// **2. Build the signature base string.**
/// The spec requires the form:
/// ```
/// HTTP_METHOD & percent_encode(base_url) & percent_encode(normalized_params)
/// ```
/// `sortedURLString(urlEscape: true)` produces
/// `percent_encode(base_url) & percent_encode(sorted_key=value_pairs)` —
/// the last two components joined with an unencoded `&`. Prepending the HTTP
/// method completes the base string.
///
/// **3. Sign.**
/// HMAC-SHA1 with key `"apiSecret&tokenSecret"`. When `oauthTokenSecret` is nil
/// (the request-token step), the key becomes `"apiSecret&"` — the trailing `&`
/// is mandatory even with an empty token secret (spec §3.4.2).
///
/// **4. Append signature and build the final URL.**
/// `oauth_signature` is added to the parameter map, then
/// `sortedURLString(urlEscape: false)` produces the final `base_url?k=v&...` URL.
///
/// - Parameters:
///   - apiSecret: Flickr application secret (OAuth "consumer secret").
///   - url: Flickr REST or OAuth endpoint URL string.
///   - parameters: All OAuth + API parameters except `oauth_signature`.
///   - oauthTokenSecret: User's access-token secret, or `nil` at the request-token step.
///   - httpMethod: `"GET"` for read operations, `"POST"` for write operations.
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

/// Assembles the required OAuth 1.0a protocol parameters common to every signed request.
///
/// **Always-present fields (OAuth 1.0a §3.1):**
/// - `oauth_nonce`: A unique per-request random value that prevents replay attacks.
///   Stripping hyphens from a UUID gives a 32-character alphanumeric string satisfying
///   the spec's requirement for an alphanumeric nonce.
/// - `oauth_timestamp`: Unix epoch in whole seconds. Flickr rejects requests whose
///   timestamp is too far from server time (typically ±10 minutes).
/// - `oauth_consumer_key`: Your Flickr API key.
/// - `oauth_signature_method`: Always `"HMAC-SHA1"` for this library.
/// - `oauth_version`: Always `"1.0"`.
///
/// **Conditionally included fields:**
/// - `oauth_callback`: Request-token step only — where Flickr should redirect the
///   user after they authorise the app.
/// - `oauth_token`: The temporary request token (access-token exchange) or the
///   permanent access token (authenticated write operations).
/// - `oauth_verifier`: Access-token exchange step only — the one-time verifier code
///   Flickr appends to the callback redirect URL.
/// - `method`, `format`, `nojsoncallback`: Flickr REST envelope parameters.
///   `nojsoncallback=1` removes the JSONP wrapper; `format=json` requests JSON output.
/// - `photo_id`, `comment_text`: Flickr method-specific payload parameters.
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
    let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
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

/// Produces either the percent-encoded signature base-string component or the final
/// request URL, controlled by `urlEscape`.
///
/// ### Why sorting is required
/// OAuth 1.0a §3.4.1.3 requires parameters to be sorted lexicographically by key
/// before joining with `&`. A dictionary's iteration order is undefined in Swift, so
/// explicit sorting is always necessary.
///
/// ### Two output modes
/// - **`urlEscape: true`** (signature base string component):
///   Each parameter value is RFC 3986-encoded, then all `key=value` pairs are joined
///   with `&`. The resulting parameter string and the base URL are each individually
///   RFC 3986-encoded, then joined with a literal `&`. This produces the
///   `percent_encode(base_url) & percent_encode(normalized_params)` component that
///   gets prepended with the HTTP method to form the complete signature base string.
///
/// - **`urlEscape: false`** (final request URL):
///   Individual parameter *values* are still RFC 3986-encoded (via `oauthEncodedString`),
///   but the URL itself is not re-encoded as a whole. Produces `base_url?k1=v1&k2=v2...`.
///
/// ### Why two named aliases (`urlEncodedString` / `oauthEncodedString`)?
/// Both delegate to `rfc3986Encoded`. The aliases exist so the two call sites read
/// naturally in context (encoding a URL vs. encoding a parameter value) without
/// introducing two separate implementations that could diverge.
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

private func urlEncodedString(string: String) -> String { rfc3986Encoded(string) }
private func oauthEncodedString(string: String) -> String { rfc3986Encoded(string) }

/// RFC 3986 percent-encoding — only unreserved characters pass through unencoded.
/// Internal (not `private`) so unit tests can call it directly.
///
/// ### Why not `URLComponents` or Foundation's built-in query encoding?
/// Foundation's query-encoding helpers permit characters such as `+`, `=`, `&`, `@`,
/// `:`, and `!` to pass through unencoded because they are legal in URL query strings.
/// OAuth 1.0a §3.6 is stricter: only the unreserved set
/// `ALPHA / DIGIT / "-" / "." / "_" / "~"` may appear unencoded; everything else
/// must be `%XX`-encoded. `addingPercentEncoding(withAllowedCharacters:)` with an
/// exact unreserved `CharacterSet` satisfies this requirement precisely.
///
/// The `?? ""` fallback is unreachable in practice: `addingPercentEncoding` returns
/// nil only for strings containing unpaired UTF-16 surrogates, which cannot appear
/// in normal Swift `String` values.
func rfc3986Encoded(_ string: String) -> String {
    let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
}

/// HMAC-SHA1 over `string` using `key`, returned as Base64.
/// Internal (not `private`) so unit tests can verify against known RFC 2202 test vectors.
///
/// This is the OAuth 1.0a signature primitive (§3.4.2). `CommonCrypto.CCHmac` writes
/// a 20-byte (`CC_SHA1_DIGEST_LENGTH`) digest into the pre-allocated `digest` buffer.
/// The digest is Base64-encoded to produce the `oauth_signature` value.
///
/// `CommonCrypto` is used rather than `CryptoKit` to maintain compatibility with
/// macOS 12 and iOS 16 without requiring `@available` guards on calling code.
func hmacsha1EncryptedString(string: String, key: String) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key, key.utf8.count, string, string.utf8.count, &digest)
    return Data(digest).base64EncodedString()
}

