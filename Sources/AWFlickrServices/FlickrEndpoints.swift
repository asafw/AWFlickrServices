//
//  FlickrEndpoints.swift
//
//
//  Created by Asaf Weinberg on 7/2/20.
//

/// Namespace for all Flickr API URL strings and method names.
enum FlickrEndpoints {
    static let hostURL = "https://api.flickr.com/services/rest/"
    static let searchEndpoint = "flickr.photos.search"
    static let getFavoritesEndPoint = "flickr.favorites.getList"
    static let faveEndpoint = "flickr.favorites.add"
    static let unFaveEndpoint = "flickr.favorites.remove"
    static let commentEndpoint = "flickr.photos.comments.addComment"
    static let infoEndpoint = "flickr.photos.getInfo"
    static let commentsEndpoint = "flickr.photos.comments.getList"
    static let requestTokenEndpoint = "https://www.flickr.com/services/oauth/request_token"
    static let authorizeEndpoint = "https://www.flickr.com/services/oauth/authorize"
    static let accessTokenEndpoint = "https://www.flickr.com/services/oauth/access_token"
    static let thumbnailPhotoUrlTemplate = "https://farm%@.staticflickr.com/%@/%@_%@_s.jpg"
    static let largePhotoUrlTemplate = "https://farm%@.staticflickr.com/%@/%@_%@_b.jpg"
}
