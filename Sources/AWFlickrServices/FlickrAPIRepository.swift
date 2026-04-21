//
//  FlickrAPIRepository.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit

struct FlickrAPIRepository {

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest,
        completion: @escaping (Result<[FlickrPhoto], Error>) -> Void
    ) {
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
            completion(.failure(FlickrAPIError.parsingError))
            return
        }
        session.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError))
                return
            }
            do {
                let photosResponse = try JSONDecoder().decode(FlickrPhotosResponse.self, from: data)
                completion(.success(photosResponse.photos.photo))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func getImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        session.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError))
                return
            }
            guard let image = UIImage(data: data) else {
                completion(.failure(FlickrAPIError.downloadImageError))
                return
            }
            completion(.success(image))
        }.resume()
    }

    func getRequestToken(
        apiKey: String,
        apiSecret: String,
        callbackUrlString: String,
        completion: @escaping (Result<RequestTokenResponse, Error>) -> Void
    ) {
        guard let url = generateRequestTokenURL(
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: callbackUrlString
        ) else { completion(.failure(FlickrAPIError.parsingError)); return }
        session.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError))
                return
            }
            guard
                let responseString = String(data: data, encoding: .utf8),
                let decoded = responseString.removingPercentEncoding
            else {
                completion(.failure(FlickrAPIError.parsingError))
                return
            }
            var dict = [String: String]()
            decoded.components(separatedBy: "&").forEach {
                let parts = $0.components(separatedBy: "=")
                if parts.count == 2 { dict[parts[0]] = parts[1] }
            }
            guard
                let confirmed = dict["oauth_callback_confirmed"],
                let token = dict["oauth_token"],
                let secret = dict["oauth_token_secret"]
            else {
                completion(.failure(FlickrAPIError.parsingError))
                return
            }
            completion(.success(RequestTokenResponse(
                oauth_callback_confirmed: confirmed,
                oauth_token: token,
                oauth_token_secret: secret
            )))
        }.resume()
    }

    func getAccessToken(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        oauthVerifier: String,
        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void
    ) {
        guard let url = generateAccessTokenURL(
            apiKey: apiKey,
            apiSecret: apiSecret,
            oauthToken: oauthToken,
            oauthTokenSecret: oauthTokenSecret,
            oauthVerifier: oauthVerifier
        ) else { completion(.failure(FlickrAPIError.parsingError)); return }
        session.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError))
                return
            }
            guard
                let responseString = String(data: data, encoding: .utf8),
                let decoded = responseString.removingPercentEncoding
            else {
                completion(.failure(FlickrAPIError.parsingError))
                return
            }
            var dict = [String: String]()
            decoded.components(separatedBy: "&").forEach {
                let parts = $0.components(separatedBy: "=")
                if parts.count == 2 { dict[parts[0]] = parts[1] }
            }
            guard
                let fullName = dict["fullname"],
                let token = dict["oauth_token"],
                let tokenSecret = dict["oauth_token_secret"],
                let nsid = dict["user_nsid"],
                let username = dict["username"]
            else {
                completion(.failure(FlickrAPIError.parsingError))
                return
            }
            completion(.success(AccessTokenResponse(
                fullname: fullName,
                oauth_token: token,
                oauth_token_secret: tokenSecret,
                user_nsid: nsid,
                username: username
            )))
        }.resume()
    }

    func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = generateFaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { completion(.failure(FlickrAPIError.parsingError)); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { _, response, error in
            if let error { completion(.failure(error)); return }
            guard validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError)); return
            }
            completion(.success(()))
        }.resume()
    }

    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = generateUnfaveURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: faveRequest.photo_id
        ) else { completion(.failure(FlickrAPIError.parsingError)); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { _, response, error in
            if let error { completion(.failure(error)); return }
            guard validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError)); return
            }
            completion(.success(()))
        }.resume()
    }

    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = generateCommentURL(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            photoId: commentRequest.photo_id, commentText: commentRequest.comment_text
        ) else { completion(.failure(FlickrAPIError.parsingError)); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { _, response, error in
            if let error { completion(.failure(error)); return }
            guard validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError)); return
            }
            completion(.success(()))
        }.resume()
    }

    func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest,
        completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void
    ) {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.infoEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": infoRequest.photo_id,
            "secret": infoRequest.secret,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            completion(.failure(FlickrAPIError.parsingError)); return
        }
        session.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError)); return
            }
            do {
                completion(.success(try JSONDecoder().decode(FlickrInfoResponse.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        let queryParams: [String: String] = [
            "method": FlickrEndpoints.commentsEndpoint,
            "api_key": apiKey,
            "nojsoncallback": "1",
            "format": "json",
            "photo_id": commentsRequest.photo_id,
        ]
        guard let url = generateURL(urlString: FlickrEndpoints.hostURL, queryParams: queryParams) else {
            completion(.failure(FlickrAPIError.parsingError)); return
        }
        session.dataTask(with: URLRequest(url: url)) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let data, validateHTTPResponse(response) else {
                completion(.failure(FlickrAPIError.networkError)); return
            }
            do {
                let commentsResponse = try JSONDecoder().decode(FlickrCommentsResponse.self, from: data)
                let comments = commentsResponse.comments.comment?.map { $0.content } ?? []
                completion(.success(comments))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Private helpers

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
