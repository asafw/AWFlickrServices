//
//  FlickrPhotosProtocol.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation

public protocol FlickrPhotosProtocol {
    func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest,
        completion: @escaping (Result<[FlickrPhoto], Error>) -> Void
    )

    func downloadImageData(
        from url: URL,
        completion: @escaping (Result<Data, Error>) -> Void
    )

    func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest,
        completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void
    )

    func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest,
        completion: @escaping (Result<[String], Error>) -> Void
    )
}

extension FlickrPhotosProtocol {

    // A single repository instance per call; defaults to URLSession.shared.
    private var repository: FlickrAPIService { FlickrAPIService() }

    public func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest,
        completion: @escaping (Result<[FlickrPhoto], Error>) -> Void
    ) {
        repository.getPhotos(apiKey: apiKey, photosRequest: photosRequest, completion: completion)
    }

    public func downloadImageData(
        from url: URL,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        repository.downloadImageData(from: url, completion: completion)
    }

    public func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        repository.fave(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            faveRequest: faveRequest, completion: completion
        )
    }

    public func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        repository.unfave(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            faveRequest: faveRequest, completion: completion
        )
    }

    public func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        repository.comment(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            commentRequest: commentRequest, completion: completion
        )
    }

    public func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest,
        completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void
    ) {
        repository.getInfo(apiKey: apiKey, infoRequest: infoRequest, completion: completion)
    }

    public func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        repository.getComments(apiKey: apiKey, commentsRequest: commentsRequest, completion: completion)
    }

    // MARK: - Async/await overloads

    /// Searches Flickr for photos matching the given request.
    public func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest
    ) async throws -> [FlickrPhoto] {
        try await withCheckedThrowingContinuation { continuation in
            getPhotos(apiKey: apiKey, photosRequest: photosRequest) { continuation.resume(with: $0) }
        }
    }

    /// Downloads raw image bytes from the given URL.
    public func downloadImageData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            downloadImageData(from: url) { continuation.resume(with: $0) }
        }
    }

    /// Marks a photo as a favourite.
    public func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            fave(
                apiKey: apiKey, apiSecret: apiSecret,
                oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
                faveRequest: faveRequest
            ) { continuation.resume(with: $0) }
        }
    }

    /// Removes a photo from favourites.
    public func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unfave(
                apiKey: apiKey, apiSecret: apiSecret,
                oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
                faveRequest: faveRequest
            ) { continuation.resume(with: $0) }
        }
    }

    /// Posts a comment on a photo.
    public func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            comment(
                apiKey: apiKey, apiSecret: apiSecret,
                oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
                commentRequest: commentRequest
            ) { continuation.resume(with: $0) }
        }
    }

    /// Fetches metadata for a single photo.
    public func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest
    ) async throws -> FlickrInfoResponse {
        try await withCheckedThrowingContinuation { continuation in
            getInfo(apiKey: apiKey, infoRequest: infoRequest) { continuation.resume(with: $0) }
        }
    }

    /// Returns all comment texts on a photo.
    public func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest
    ) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            getComments(apiKey: apiKey, commentsRequest: commentsRequest) { continuation.resume(with: $0) }
        }
    }
}
