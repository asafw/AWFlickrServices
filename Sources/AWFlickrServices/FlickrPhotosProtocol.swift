//
//  FlickrPhotosProtocol.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

import UIKit

protocol FlickrPhotosProtocol {
    func getPhotos(apiKey: String,
                   photosRequest: PhotosRequest,
                   completion: @escaping (Result<[Photo], Error>) -> Void)
    
    func getImage(from url: URL,
                  completion: @escaping (Result<UIImage, Error>) -> Void)
    
    func fave(apiKey: String,
              apiSecret: String,
              oauthToken: String,
              oauthTokenSecret: String,
              faveRequest: FaveRequest,
              completion: @escaping (Result<Void, Error>) -> Void)
    
    func unfave(apiKey: String,
                apiSecret: String,
                oauthToken: String,
                oauthTokenSecret: String,
                faveRequest: FaveRequest,
                completion: @escaping (Result<Void, Error>) -> Void)
    
    func comment(apiKey: String,
                 apiSecret: String,
                 oauthToken: String,
                 oauthTokenSecret: String,
                 commentRequest: CommentRequest,
                 completion: @escaping (Result<Void, Error>) -> Void)
    
    func getInfo(apiKey: String,
                 infoRequest: InfoRequest,
                 completion: @escaping (Result<InfoResponse, Error>) -> Void)
    
    func getComments(apiKey: String,
                     commentsRequest: CommentsRequest,
                     completion: @escaping (Result<[String], Error>) -> Void)
}

extension FlickrPhotosProtocol {
    func getPhotos(apiKey: String,
                   photosRequest: PhotosRequest,
                   completion: @escaping (Result<[Photo], Error>) -> Void) {
        FlickrAPIRepository().getPhotos(apiKey: apiKey,
                                        photosRequest: photosRequest,
                                        completion: completion)
    }
    
    func getImage(from url: URL,
                  completion: @escaping (Result<UIImage, Error>) -> Void) {
        FlickrAPIRepository().getImage(from: url,
                                       completion: completion)
    }
    
    func fave(apiKey: String,
              apiSecret: String,
              oauthToken: String,
              oauthTokenSecret: String,
              faveRequest: FaveRequest,
              completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().fave(apiKey: apiKey,
                                   apiSecret: apiSecret,
                                   oauthToken: oauthToken,
                                   oauthTokenSecret: oauthTokenSecret,
                                   faveRequest: faveRequest,
                                   completion: completion)
    }
    
    func unfave(apiKey: String,
                apiSecret: String,
                oauthToken: String,
                oauthTokenSecret: String,
                faveRequest: FaveRequest,
                completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().unfave(apiKey: apiKey,
                                     apiSecret: apiSecret,
                                     oauthToken: oauthToken,
                                     oauthTokenSecret: oauthTokenSecret,
                                     faveRequest: faveRequest,
                                     completion: completion)
    }
    
    func comment(apiKey: String,
                 apiSecret: String,
                 oauthToken: String,
                 oauthTokenSecret: String,
                 commentRequest: CommentRequest,
                 completion: @escaping (Result<Void, Error>) -> Void) {
        FlickrAPIRepository().comment(apiKey: apiKey,
                                      apiSecret: apiSecret,
                                      oauthToken: oauthToken,
                                      oauthTokenSecret: oauthTokenSecret,
                                      commentRequest: commentRequest,
                                      completion: completion)
    }
    
    func getInfo(apiKey: String,
                 infoRequest: InfoRequest,
                 completion: @escaping (Result<InfoResponse, Error>) -> Void) {
        FlickrAPIRepository().getInfo(apiKey: apiKey,
                                      infoRequest: infoRequest,
                                      completion: completion)
    }
    
    func getComments(apiKey: String,
                     commentsRequest: CommentsRequest,
                     completion: @escaping (Result<[String], Error>) -> Void) {
        FlickrAPIRepository().getComments(apiKey: apiKey,
                                          commentsRequest: commentsRequest,
                                          completion: completion)
    }
}
