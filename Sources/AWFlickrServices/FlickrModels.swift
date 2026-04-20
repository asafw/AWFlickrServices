//
//  FlickrModels.swift
//
//  
//  Created by Asaf Weinberg on 7/2/20.
//

/// A single Flickr photo returned from a search or faves response.
public struct FlickrPhoto: Decodable, Sendable {
    public let id: String
    let owner: String?
    public let secret: String
    let server: String
    let farm: Int
    public let title: String

    /// Returns the URL string for the small-square thumbnail (75×75 px).
    public func thumbnailPhotoURLString() -> String {
        String(format: FlickrEndpoints.thumbnailPhotoUrlTemplate, String(farm), server, id, secret)
    }

    /// Returns the URL string for the large photo (up to 1024px on longest side).
    public func largePhotoURLString() -> String {
        String(format: FlickrEndpoints.largePhotoUrlTemplate, String(farm), server, id, secret)
    }
}

struct FlickrPhotos: Decodable {
    let page: Int?
    let pages: Int?
    let perpage: Int?
    let total: Int?
    let photo: [FlickrPhoto]
}

struct FlickrPhotosResponse: Decodable {
    let photos: FlickrPhotos
}

/// Parameters for a Flickr photo search request.
public struct FlickrPhotosRequest: Encodable, Sendable {
    public let text: String
    public let page: Int
    public let per_page: Int

    public init(text: String, page: Int, per_page: Int) {
        self.text = text
        self.page = page
        self.per_page = per_page
    }
}

/// Request model for faving or unfaving a photo.
public struct FlickrFaveRequest: Encodable, Sendable {
    public let photo_id: String

    public init(photo_id: String) {
        self.photo_id = photo_id
    }
}

/// Request model for posting a comment on a photo.
public struct FlickrCommentRequest: Encodable, Sendable {
    public let photo_id: String
    public let comment_text: String

    public init(photo_id: String, comment_text: String) {
        self.photo_id = photo_id
        self.comment_text = comment_text
    }
}

/// Request model for fetching info about a specific photo.
public struct FlickrInfoRequest: Encodable, Sendable {
    public let photo_id: String
    public let secret: String

    public init(photo_id: String, secret: String) {
        self.photo_id = photo_id
        self.secret = secret
    }
}

/// Top-level response from `flickr.photos.getInfo`.
public struct FlickrInfoResponse: Decodable, Sendable {
    public let photo: PhotoInfo
}

public struct PhotoInfo: Decodable, Sendable {
    public let owner: Owner
    public let dates: Dates
    public let views: String
}

public struct Owner: Decodable, Sendable {
    public let realname: String
    public let location: String?
}

public struct Dates: Decodable, Sendable {
    public let taken: String
}

/// Request model for fetching comments on a photo.
public struct FlickrCommentsRequest: Encodable, Sendable {
    let photo_id: String

    public init(photo_id: String) {
        self.photo_id = photo_id
    }
}

struct FlickrCommentsResponse: Decodable {
    let comments: CommentInfo
}

struct CommentInfo: Decodable {
    let comment: [Comment]?
}

struct Comment: Decodable {
    let content: String

    private enum CodingKeys: String, CodingKey {
        case content = "_content"
    }
}

