//
//  FlickrEndpoints.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

struct FlickrEndpoints {
    let hostURL = "https://api.flickr.com/services/rest/"
    let searchEndpoint = "flickr.photos.search"
    let getFavoritesEndPoint = "flickr.favorites.getList"
    let faveEndpoint = "flickr.favorites.add"
    let unFaveEndpoint = "flickr.favorites.remove"
    let commentEndpoint = "flickr.photos.comments.addComment"
    let permsEndpoint = "flickr.photos.getPerms"
    let infoEndpoint = "flickr.photos.getInfo"
    let commentsEndpoint = "flickr.photos.comments.getList"
    let requestTokenEndpoint = "https://www.flickr.com/services/oauth/request_token"
    let authorizeEndpoint = "https://www.flickr.com/services/oauth/authorize"
    let accessTokenEndpoint = "https://www.flickr.com/services/oauth/access_token"
    let thumbnailPhotoUrlTemplate = "https://farm%@.staticflickr.com/%@/%@_%@_s.jpg"
    let largePhotoUrlTemplate = "https://farm%@.staticflickr.com/%@/%@_%@_b.jpg"
}
