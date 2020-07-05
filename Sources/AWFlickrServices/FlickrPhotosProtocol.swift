//
//  FlickrPhotosProtocol.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit

public protocol FlickrPhotosProtocol {
    func getPhotos(apiKey: String,
                   photosRequest: FlickrPhotosRequest,
                   completion: @escaping (Result<[FlickrPhoto], Error>) -> Void)
    
    func getImage(from url: URL,
                  completion: @escaping (Result<UIImage, Error>) -> Void)
    
    func fave(apiKey: String,
              apiSecret: String,
              oauthToken: String,
              oauthTokenSecret: String,
              faveRequest: FlickrFaveRequest,
              completion: @escaping (Result<Void, Error>) -> Void)
    
    func unfave(apiKey: String,
                apiSecret: String,
                oauthToken: String,
                oauthTokenSecret: String,
                faveRequest: FlickrFaveRequest,
                completion: @escaping (Result<Void, Error>) -> Void)
    
    func comment(apiKey: String,
                 apiSecret: String,
                 oauthToken: String,
                 oauthTokenSecret: String,
                 commentRequest: FlickrCommentRequest,
                 completion: @escaping (Result<Void, Error>) -> Void)
    
    func getInfo(apiKey: String,
                 infoRequest: FlickrInfoRequest,
                 completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void)
    
    func getComments(apiKey: String,
                     commentsRequest: FlickrCommentsRequest,
                     completion: @escaping (Result<[String], Error>) -> Void)
}

extension FlickrPhotosProtocol {
    public func getPhotos(apiKey: String,
                          photosRequest: FlickrPhotosRequest,
                          completion: @escaping (Result<[FlickrPhoto], Error>) -> Void) {
        FlickrAPIRepository().getPhotos(apiKey: apiKey,
                                        photosRequest: photosRequest,
                                        completion: completion)
    }
    
    public func getImage(from url: URL,
                         completion: @escaping (Result<UIImage, Error>) -> Void) {
        FlickrAPIRepository().getImage(from: url,
                                       completion: completion)
    }
    
    public func fave(apiKey: String,
                     apiSecret: String,
                     oauthToken: String,
                     oauthTokenSecret: String,
                     faveRequest: FlickrFaveRequest,
                     completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().fave(apiKey: apiKey,
                                   apiSecret: apiSecret,
                                   oauthToken: oauthToken,
                                   oauthTokenSecret: oauthTokenSecret,
                                   faveRequest: faveRequest,
                                   completion: completion)
    }
    
    public func unfave(apiKey: String,
                       apiSecret: String,
                       oauthToken: String,
                       oauthTokenSecret: String,
                       faveRequest: FlickrFaveRequest,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().unfave(apiKey: apiKey,
                                     apiSecret: apiSecret,
                                     oauthToken: oauthToken,
                                     oauthTokenSecret: oauthTokenSecret,
                                     faveRequest: faveRequest,
                                     completion: completion)
    }
    
    public func comment(apiKey: String,
                        apiSecret: String,
                        oauthToken: String,
                        oauthTokenSecret: String,
                        commentRequest: FlickrCommentRequest,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().comment(apiKey: apiKey,
                                      apiSecret: apiSecret,
                                      oauthToken: oauthToken,
                                      oauthTokenSecret: oauthTokenSecret,
                                      commentRequest: commentRequest,
                                      completion: completion)
    }
    
    public func getInfo(apiKey: String,
                        infoRequest: FlickrInfoRequest,
                        completion: @escaping (Result<FlickrInfoResponse, Error>) -> Void) {
        FlickrAPIRepository().getInfo(apiKey: apiKey,
                                      infoRequest: infoRequest,
                                      completion: completion)
    }
    
    public func getComments(apiKey: String,
                            commentsRequest: FlickrCommentsRequest,
                            completion: @escaping (Result<[String], Error>) -> Void) {
        FlickrAPIRepository().getComments(apiKey: apiKey,
                                          commentsRequest: commentsRequest,
                                          completion: completion)
    }
}
