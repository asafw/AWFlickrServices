//
//  FlickrAPIRepository.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit

struct FlickrAPIRepository {
    
    func getPhotos(apiKey: String,
                   photosRequest: FlickrPhotosRequest,
                   completion: @escaping (Result<[FlickrPhoto], Error>) -> Void) {
        let queryParams = ["method" : FlickrEndpoints().searchEndpoint, "api_key" : apiKey,
                           "per_page" : String(photosRequest.per_page), "page" : String(photosRequest.page),
                           "nojsoncallback": "1", "format": "json", "text" : photosRequest.text]
        guard let urlWithQueryParams = generateURL(urlString: FlickrEndpoints().hostURL, queryParams: queryParams) else {
            completion(.failure(FlickrAPIError.parsingError))
            return
        }
        let request = URLRequest(url: urlWithQueryParams)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            do {
                let photosResponse = try JSONDecoder().decode(FlickrPhotosResponse.self, from: data)
                completion(.success(photosResponse.photos.photo))
            } catch let error {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func generateURL(urlString: String,
                             queryParams: [String : String]? = nil) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let queryParams = queryParams {
            urlComponents?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return urlComponents?.url
    }
    
    func getImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        URLSession.shared.dataTask(with: url)  { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            if let image = UIImage(data: data) {
                completion(.success(image))
            }
            else {
                completion(.failure(FlickrAPIError.downloadImageError))
            }
        }.resume()
    }
    
    func getRequestToken(apiKey: String,
                         apiSecret: String,
                         callbackUrlString: String,
                         completion: @escaping (Result<RequestTokenResponse, Error>) -> Void) {
        guard let requestTokenURL = generateRequestTokenURL(apiKey: apiKey,
                                                            apiSecret: apiSecret,
                                                            callbackUrlString: callbackUrlString) else { return }
        let request = URLRequest(url: requestTokenURL)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            guard let responseString = String(data: data, encoding: String.Encoding.utf8),
                let parameters = responseString.removingPercentEncoding?.components(separatedBy: "&") else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
            }
            var dictionary = [String: String]()
            parameters.forEach {
                let components = $0.components(separatedBy: "=")
                let key = components[0]
                let value = components[1]
                dictionary[key] = value
            }
            guard let oauthCallbackConfirmed = dictionary["oauth_callback_confirmed"],
                let oauthToken = dictionary["oauth_token"],
                let oauthTokenSecret = dictionary["oauth_token_secret"] else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
            }
            let requestTokenResponse = RequestTokenResponse(oauth_callback_confirmed: oauthCallbackConfirmed,
                                                            oauth_token: oauthToken,
                                                            oauth_token_secret: oauthTokenSecret)
            completion(.success(requestTokenResponse))
        }.resume()
    }
    
    func getAccessToken(apiKey: String,
                        apiSecret: String,
                        oauthToken: String,
                        oauthTokenSecret: String,
                        oauthVerifier: String,
                        completion: @escaping (Result<AccessTokenResponse, Error>) -> Void) {
        guard let accessTokenURL = generateAccessTokenURL(apiKey: apiKey,
                                                          apiSecret: apiSecret,
                                                          oauthToken: oauthToken,
                                                          oauthTokenSecret: oauthTokenSecret,
                                                          oauthVerifier: oauthVerifier) else { return }
        let request = URLRequest(url: accessTokenURL)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            guard let responseString = String(data: data, encoding: String.Encoding.utf8),
                let parameters = responseString.removingPercentEncoding?.components(separatedBy: "&") else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
            }
            var dictionary = [String: String]()
            parameters.forEach {
                let components = $0.components(separatedBy: "=")
                let key = components[0]
                let value = components[1]
                dictionary[key] = value
            }
            guard let fullName = dictionary["fullname"],
                let oauthToken = dictionary["oauth_token"],
                let oauthTokenSecret = dictionary["oauth_token_secret"],
                let userNsid = dictionary["user_nsid"],
                let userName = dictionary["username"]  else {
                    completion(.failure(FlickrAPIError.parsingError))
                    return
            }
            let accessTokenResponse = AccessTokenResponse(fullname: fullName,
                                                          oauth_token: oauthToken,
                                                          oauth_token_secret: oauthTokenSecret,
                                                          user_nsid: userNsid,
                                                          username: userName)
            completion(.success(accessTokenResponse))
        }.resume()
    }
    
    func fave(apiKey: String,
              apiSecret: String,
              oauthToken: String,
              oauthTokenSecret: String,
              faveRequest: FlickrFaveRequest,
              completion: @escaping (Result<Void, Error>) -> Void) {
        guard let faveURL = generateFaveURL(apiKey: apiKey,
                                            apiSecret: apiSecret,
                                            oauthToken: oauthToken,
                                            oauthTokenSecret: oauthTokenSecret,
                                            photoId: faveRequest.photo_id) else {
                                                completion(.failure(FlickrAPIError.parsingError))
                                                return
        }
        
        var request = URLRequest(url: faveURL)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func unfave(apiKey: String,
                apiSecret: String,
                oauthToken: String,
                oauthTokenSecret: String,
                faveRequest: FlickrFaveRequest,
                completion: @escaping (Result<Void, Error>) -> Void) {
        guard let faveURL = generateUnfaveURL(apiKey: apiKey,
                                              apiSecret: apiSecret,
                                              oauthToken: oauthToken,
                                              oauthTokenSecret: oauthTokenSecret,
                                              photoId: faveRequest.photo_id) else {
                                                completion(.failure(FlickrAPIError.parsingError))
                                                return
        }
        
        var request = URLRequest(url: faveURL)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func comment(apiKey: String,
                 apiSecret: String,
                 oauthToken: String,
                 oauthTokenSecret: String,
                 commentRequest: FlickrCommentRequest,
                 completion: @escaping (Result<Void, Error>) -> Void) {
        guard let commentURL = generateCommentURL(apiKey: apiKey,
                                                  apiSecret: apiSecret,
                                                  oauthToken: oauthToken,
                                                  oauthTokenSecret: oauthTokenSecret,
                                                  photoId: commentRequest.photo_id,
                                                  commentText: commentRequest.comment_text) else {
                                                    completion(.failure(FlickrAPIError.parsingError))
                                                    return
        }
        
        var request = URLRequest(url: commentURL)
        request.httpMethod = "POST"
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func getInfo(apiKey: String,
                 infoRequest: FlickrInfoRequest,
                 completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void) {
        let queryParams = ["method" : FlickrEndpoints().infoEndpoint, "api_key" : apiKey,
                           "nojsoncallback": "1", "format": "json", "photo_id" : infoRequest.photo_id, "secret" : infoRequest.secret]
        guard let urlWithQueryParams = generateURL(urlString: FlickrEndpoints().hostURL, queryParams: queryParams) else {
            completion(.failure(FlickrAPIError.parsingError))
            return
        }
        let request = URLRequest(url: urlWithQueryParams)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            do {
                let infoResponse = try JSONDecoder().decode(FlickrInfoResponse.self, from: data)
                completion(.success(infoResponse))
            } catch let error {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func getComments(apiKey: String,
                     commentsRequest: FlickrCommentsRequest,
                     completion: @escaping (Result<[String], Error>) -> Void) {
        let queryParams = ["method" : FlickrEndpoints().commentsEndpoint, "api_key" : apiKey,
                           "nojsoncallback": "1", "format": "json", "photo_id" : commentsRequest.photo_id]
        guard let urlWithQueryParams = generateURL(urlString: FlickrEndpoints().hostURL, queryParams: queryParams) else {
            completion(.failure(FlickrAPIError.parsingError))
            return
        }
        let request = URLRequest(url: urlWithQueryParams)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(error ?? FlickrAPIError.networkError))
                return
            }
            do {
                let commentsResponse = try JSONDecoder().decode(FlickrCommentsResponse.self, from: data)
                let comments = commentsResponse.comments.comment?.map { $0._content } ?? []
                completion(.success(comments))
            } catch let error {
                completion(.failure(error))
            }
        }.resume()
    }
}
