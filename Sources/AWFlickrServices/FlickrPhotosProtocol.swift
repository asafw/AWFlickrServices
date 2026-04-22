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
}
