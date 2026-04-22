//
//  FlickrPhotosProtocol.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation

public protocol FlickrPhotosProtocol {

    /// The `URLSession` used by the default method implementations.
    ///
    /// Override to inject a custom session — for example, a `URLProtocol`-backed
    /// ephemeral session for unit tests, or a session with a custom
    /// `URLSessionConfiguration` for production tuning.
    ///
    /// ### Design rationale
    /// The internal `FlickrAPIService` type holds the actual HTTP logic and takes
    /// a `URLSession` at init. Exposing `FlickrAPIService` publicly would leak an
    /// implementation detail into the public API surface. Exposing `URLSession`
    /// instead gives consumers full session control (timeouts, caching, protocol
    /// interception) without committing to any internal type. The default
    /// implementation in the protocol extension returns `URLSession.shared`, so
    /// conforming types that do not need customisation pay zero overhead.
    var urlSession: URLSession { get }

    /// Searches Flickr for photos matching the given request.
    func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest
    ) async throws -> [FlickrPhoto]

    /// Downloads raw image bytes from the given URL.
    func downloadImageData(from url: URL) async throws -> Data

    /// Marks a photo as a favourite.
    func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws

    /// Removes a photo from favourites.
    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws

    /// Posts a comment on a photo.
    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest
    ) async throws

    /// Fetches metadata for a single photo.
    func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest
    ) async throws -> FlickrInfoResponse

    /// Returns all comment texts on a photo.
    func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest
    ) async throws -> [String]
}

public extension FlickrPhotosProtocol {

    var urlSession: URLSession { .shared }

    private var service: FlickrAPIService { FlickrAPIService(session: urlSession) }

    func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest
    ) async throws -> [FlickrPhoto] {
        try await service.getPhotos(apiKey: apiKey, photosRequest: photosRequest)
    }

    func downloadImageData(from url: URL) async throws -> Data {
        try await service.downloadImageData(from: url)
    }

    func fave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws {
        try await service.fave(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            faveRequest: faveRequest
        )
    }

    func unfave(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        faveRequest: FlickrFaveRequest
    ) async throws {
        try await service.unfave(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            faveRequest: faveRequest
        )
    }

    func comment(
        apiKey: String,
        apiSecret: String,
        oauthToken: String,
        oauthTokenSecret: String,
        commentRequest: FlickrCommentRequest
    ) async throws {
        try await service.comment(
            apiKey: apiKey, apiSecret: apiSecret,
            oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
            commentRequest: commentRequest
        )
    }

    func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest
    ) async throws -> FlickrInfoResponse {
        try await service.getInfo(apiKey: apiKey, infoRequest: infoRequest)
    }

    func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest
    ) async throws -> [String] {
        try await service.getComments(apiKey: apiKey, commentsRequest: commentsRequest)
    }
}
