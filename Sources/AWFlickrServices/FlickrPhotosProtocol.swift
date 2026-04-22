//
//  FlickrPhotosProtocol.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import Foundation

public protocol FlickrPhotosProtocol {
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

    private var service: FlickrAPIService { FlickrAPIService() }

    public func getPhotos(
        apiKey: String,
        photosRequest: FlickrPhotosRequest
    ) async throws -> [FlickrPhoto] {
        try await service.getPhotos(apiKey: apiKey, photosRequest: photosRequest)
    }

    public func downloadImageData(from url: URL) async throws -> Data {
        try await service.downloadImageData(from: url)
    }

    public func fave(
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

    public func unfave(
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

    public func comment(
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

    public func getInfo(
        apiKey: String,
        infoRequest: FlickrInfoRequest
    ) async throws -> FlickrInfoResponse {
        try await service.getInfo(apiKey: apiKey, infoRequest: infoRequest)
    }

    public func getComments(
        apiKey: String,
        commentsRequest: FlickrCommentsRequest
    ) async throws -> [String] {
        try await service.getComments(apiKey: apiKey, commentsRequest: commentsRequest)
    }
}
