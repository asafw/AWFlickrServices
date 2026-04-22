//
//  FlickrAPIService.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation

/// Internal HTTP layer for AWFlickrServices.
///
/// All public API access flows through the default implementations on
/// `FlickrPhotosProtocol` and `FlickrOAuthProtocol`, which instantiate a
/// `FlickrAPIService` using the conforming type's `urlSession`. This type
/// is intentionally `internal` — it is an implementation detail; consumers
/// never reference it directly.
///
/// ### Session injection
/// The `session` property is set at `init`. In production `URLSession.shared`
/// is used via the protocol extension default. In tests a
/// `URLSessionConfiguration.ephemeral` session backed by `CapturingURLProtocol`
/// is injected so requests never reach the network.
struct FlickrAPIService {

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getPhotos(
        apiKey: String,
        photosRequest: AWFlickrPhotosRequest
    ) async throws -> [AWFlickrPhoto] {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.searchEndpoint,
            "api_key": apiKey,
            "per_page": String(photosRequest.per_page),
            "page": String(photosRequest.page),
            // nojsoncallback=1 strips the JSONP wrapper Flickr adds by default.
            // format=json selects JSON output (the Flickr REST API defaults to XML).
            "nojsoncallback": "1",
            "format": "json",
            "text": photosRequest.text,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw AWFlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        let photosResponse: FlickrPhotosResponse = try decodeFlickrJSON(data)
        return photosResponse.photos.photo
    }

    func downloadImageData(from url: URL) async throws -> Data {
        // returnCacheDataElseLoad: serve from the URL cache when a prior response
        // exists, avoiding redundant network round-trips for thumbnail grids where
        // the same photo URL may be requested many times as the user scrolls.
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        return data
    }

    func getRequestToken(
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String
    ) async throws -> RequestTokenResponse {
        guard let url = generateRequestTokenURL(
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: callbackUrlString
        ) else { throw AWFlickrAPIError.parsingError }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        guard
            let responseString = String(data: data, encoding: .utf8),
            let decoded = responseString.removingPercentEncoding
        else { throw AWFlickrAPIError.parsingError }
        var dict = [String: String]()
        decoded.components(separatedBy: "&").forEach {
            // Split on the first `=` only — values can contain `=` (e.g. base64 padding)
            if let range = $0.range(of: "=") {
                let key = String($0[..<range.lowerBound])
                let value = String($0[range.upperBound...])
                if !key.isEmpty { dict[key] = value }
            }
        }
        guard
            let confirmed = dict["oauth_callback_confirmed"],
            let token = dict["oauth_token"],
            let secret = dict["oauth_token_secret"]
        else { throw AWFlickrAPIError.parsingError }
        return RequestTokenResponse(
            oauth_callback_confirmed: confirmed,
            oauth_token: token,
            oauth_token_secret: secret
        )
    }

    func getAccessToken(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        oauthVerifier: String
    ) async throws -> AWAccessTokenResponse {
        guard let url = generateAccessTokenURL(
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthToken: oauthToken,
            oauthTokenSecret: oauthTokenSecret,
            oauthVerifier: oauthVerifier
        ) else { throw AWFlickrAPIError.parsingError }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        guard
            let responseString = String(data: data, encoding: .utf8),
            let decoded = responseString.removingPercentEncoding
        else { throw AWFlickrAPIError.parsingError }
        var dict = [String: String]()
        decoded.components(separatedBy: "&").forEach {
            // Split on the first `=` only — values can contain `=` (e.g. base64 padding)
            if let range = $0.range(of: "=") {
                let key = String($0[..<range.lowerBound])
                let value = String($0[range.upperBound...])
                if !key.isEmpty { dict[key] = value }
            }
        }
        guard
            let fullName = dict["fullname"],
            let token = dict["oauth_token"],
            let tokenSecret = dict["oauth_token_secret"],
            let nsid = dict["user_nsid"],
            let username = dict["username"]
        else { throw AWFlickrAPIError.parsingError }
        return AWAccessTokenResponse(
            fullname: fullName,
            oauth_token: token,
            oauth_token_secret: tokenSecret,
            user_nsid: nsid,
            username: username
        )
    }

    func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: AWFlickrFaveRequest
    ) async throws {
        guard let url = generateFaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { throw AWFlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: AWFlickrFaveRequest
    ) async throws {
        guard let url = generateUnfaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { throw AWFlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: AWFlickrCommentRequest
    ) async throws {
        guard let url = generateCommentURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: commentRequest.photo_id, commentText: commentRequest.comment_text
        ) else { throw AWFlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func getInfo(
        apiKey: String,
        infoRequest: AWFlickrInfoRequest
    ) async throws -> AWFlickrInfoResponse {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.infoEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": infoRequest.photo_id,
            "secret": infoRequest.secret,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw AWFlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        return try decodeFlickrJSON(data)
    }

    func getComments(
        apiKey: String,
        commentsRequest: AWFlickrCommentsRequest
    ) async throws -> [String] {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.commentsEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": commentsRequest.photo_id,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw AWFlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw AWFlickrAPIError.networkError }
        let commentsResponse: FlickrCommentsResponse = try decodeFlickrJSON(data)
        return commentsResponse.comments.comment?.map { $0.content } ?? []
    }

    // MARK: - Private helpers

    /// Decodes `data` into `T`, but first checks for a Flickr API-level error envelope
    /// (`{"stat":"fail","code":...,"message":...}`). Flickr always returns HTTP 200 for
    /// API-level errors (wrong API key, photo not found, etc.), so the stat check must
    /// happen *before* attempting the full type decode — otherwise a DecodingError would
    /// surface instead of the more informative `.apiError(code:message:)`.
    ///
    /// `try?` is intentional for the envelope decode: if the response is not JSON at all,
    /// or is valid JSON of a different shape, the guard simply falls through and the real
    /// decode attempt follows (which will either succeed or throw its own `DecodingError`).
    private func decodeFlickrJSON<T: Decodable>(_ data: Data) throws -> T {
        if let envelope = try? JSONDecoder().decode(FlickrErrorEnvelope.self, from: data),
           envelope.stat == "fail" {
            throw AWFlickrAPIError.apiError(
                code: envelope.code ?? -1,
                message: envelope.message ?? "Unknown error"
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Checks `data` for a Flickr API-level `stat:fail` response without attempting
    /// a full type decode. Used by void-returning POST endpoints (`fave`, `unfave`,
    /// `comment`) where there is no expected payload to decode on success — only the
    /// presence or absence of an error envelope matters.
    private func checkFlickrError(_ data: Data) throws {
        if let envelope = try? JSONDecoder().decode(FlickrErrorEnvelope.self, from: data),
           envelope.stat == "fail" {
            throw AWFlickrAPIError.apiError(
                code: envelope.code ?? -1,
                message: envelope.message ?? "Unknown error"
            )
        }
    }

    /// Builds a URL from a base string and an optional dictionary of query parameters.
    ///
    /// `URLComponents` is used rather than string concatenation to ensure each key
    /// and value is individually percent-encoded by Foundation before being joined
    /// into the query string. Returns `nil` if `urlString` is not a valid URL — in
    /// practice this cannot occur because all callers pass compile-time constants
    /// from `FlickrEndpoints`.
    private func generateURL(urlString: String, queryParams: [String: String]? = nil) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryParams {
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components?.url
    }

    /// Returns `true` only when `response` is an `HTTPURLResponse` with a 2xx status.
    ///
    /// A non-`HTTPURLResponse` should never occur for Flickr API requests (they are
    /// always HTTP), but the cast is checked rather than forced to avoid a crash on
    /// any unexpected protocol-level response. Redirects (3xx), client errors (4xx),
    /// and server errors (5xx) all return `false` and become `.networkError`.
    /// Flickr API-level failures that arrive as HTTP 200 with a `{"stat":"fail"}` body
    /// are caught separately by `decodeFlickrJSON` / `checkFlickrError`.
    private func validateHTTPResponse(_ response: URLResponse?) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

// Minimal JSON envelope for detecting Flickr API-level errors before attempting
// a full response decode. Flickr returns HTTP 200 with this shape when a request
// is valid HTTP but invalid at the API level (wrong key, photo not found, etc.):
// {"stat": "fail", "code": 100, "message": "Invalid API Key"}.
// All fields are optional to maximise decode tolerance — only `stat` is strictly
// required, but missing code/message produce a synthetic -1 / "Unknown error".
private struct FlickrErrorEnvelope: Decodable {
    let stat: String?
    let code: Int?
    let message: String?
}
