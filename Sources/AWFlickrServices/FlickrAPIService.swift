//
//  FlickrAPIService.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation

struct FlickrAPIService {

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest
    ) async throws -> [FlickrPhoto] {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.searchEndpoint,
            "api_key": apiKey,
            "per_page": String(photosRequest.per_page),
            "page": String(photosRequest.page),
            "nojsoncallback": "1",
            "format": "json",
            "text": photosRequest.text,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw FlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        let photosResponse: FlickrPhotosResponse = try decodeFlickrJSON(data)
        return photosResponse.photos.photo
    }

    func downloadImageData(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
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
        ) else { throw FlickrAPIError.parsingError }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        guard
            let responseString = String(data: data, encoding: .utf8),
            let decoded = responseString.removingPercentEncoding
        else { throw FlickrAPIError.parsingError }
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
        else { throw FlickrAPIError.parsingError }
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
    ) async throws -> AccessTokenResponse {
        guard let url = generateAccessTokenURL(
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthToken: oauthToken,
            oauthTokenSecret: oauthTokenSecret,
            oauthVerifier: oauthVerifier
        ) else { throw FlickrAPIError.parsingError }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        guard
            let responseString = String(data: data, encoding: .utf8),
            let decoded = responseString.removingPercentEncoding
        else { throw FlickrAPIError.parsingError }
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
        else { throw FlickrAPIError.parsingError }
        return AccessTokenResponse(
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
        faveRequest: FlickrFaveRequest
    ) async throws {
        guard let url = generateFaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { throw FlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws {
        guard let url = generateUnfaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { throw FlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest
    ) async throws {
        guard let url = generateCommentURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: commentRequest.photo_id, commentText: commentRequest.comment_text
        ) else { throw FlickrAPIError.parsingError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        try checkFlickrError(data)
    }

    func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest
    ) async throws -> FlickrInfoResponse {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.infoEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": infoRequest.photo_id,
            "secret": infoRequest.secret,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw FlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        return try decodeFlickrJSON(data)
    }

    func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest
    ) async throws -> [String] {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.commentsEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": commentsRequest.photo_id,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            throw FlickrAPIError.parsingError
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard validateHTTPResponse(response) else { throw FlickrAPIError.networkError }
        let commentsResponse: FlickrCommentsResponse = try decodeFlickrJSON(data)
        return commentsResponse.comments.comment?.map { $0.content } ?? []
    }

    // MARK: - Private helpers

    /// Decodes `data` into `T`, but first checks for a Flickr API-level error envelope
    /// (`{"stat":"fail","code":...,"message":...}`). Flickr always returns HTTP 200 for
    /// API errors, so this must be checked before the real decode.
    private func decodeFlickrJSON<T: Decodable>(_ data: Data) throws -> T {
        if let envelope = try? JSONDecoder().decode(FlickrErrorEnvelope.self, from: data),
           envelope.stat == "fail" {
            throw FlickrAPIError.apiError(
                code: envelope.code ?? -1,
                message: envelope.message ?? "Unknown error"
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Checks `data` for a Flickr API-level error (`stat:fail`) without full decoding.
    /// Used by void-returning POST endpoints (fave, unfave, comment).
    private func checkFlickrError(_ data: Data) throws {
        if let envelope = try? JSONDecoder().decode(FlickrErrorEnvelope.self, from: data),
           envelope.stat == "fail" {
            throw FlickrAPIError.apiError(
                code: envelope.code ?? -1,
                message: envelope.message ?? "Unknown error"
            )
        }
    }

    private func generateURL(urlString: String, queryParams: [String: String]? = nil) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryParams {
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components?.url
    }

    private func validateHTTPResponse(_ response: URLResponse?) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

// Minimal envelope used to detect Flickr API-level errors before attempting full decodes.
private struct FlickrErrorEnvelope: Decodable {
    let stat: String?
    let code: Int?
    let message: String?
}
