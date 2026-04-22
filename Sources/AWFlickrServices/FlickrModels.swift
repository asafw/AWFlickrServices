//
//  FlickrModels.swift
//
//  
//  Created by Asaf Weinberg on 7/2/20.
//

/// A single Flickr photo returned from a search or faves response.
public struct FlickrPhoto: Decodable, Sendable {
    public let id: String
    /// Owner NSID (e.g. "12345678@N00"). Present in faves responses; may be absent
    /// in search responses depending on the requested extras parameter.
    public let owner: String?
    public let secret: String
    /// CDN server number. Combined with `farm` and `id` to build static photo URLs.
    public let server: String
    /// CDN farm index. Flickr routes image requests across numbered farm subdomains
    /// (e.g. farm2.staticflickr.com) for load balancing. Used in the URL template.
    public let farm: Int
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

// Internal decode wrapper for the nested "photos" object in Flickr search responses.
// Flickr wraps the photo array inside a "photos" key that also carries pagination
// metadata. All fields except `photo` are optional because Flickr omits them for
// some API responses and they are not used by the library.
struct FlickrPhotos: Decodable {
    let page: Int?
    let pages: Int?
    let perpage: Int?
    let total: Int?
    let photo: [FlickrPhoto]
}

// Top-level JSON envelope for `flickr.photos.search`. The actual photo array is
// nested at response.photos.photo — two levels of wrapping requiring two structs.
struct FlickrPhotosResponse: Decodable {
    let photos: FlickrPhotos
}

/// Parameters for a Flickr photo search request.
public struct FlickrPhotosRequest: Sendable {
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
public struct FlickrFaveRequest: Sendable {
    public let photo_id: String

    public init(photo_id: String) {
        self.photo_id = photo_id
    }
}

/// Request model for posting a comment on a photo.
public struct FlickrCommentRequest: Sendable {
    public let photo_id: String
    public let comment_text: String

    public init(photo_id: String, comment_text: String) {
        self.photo_id = photo_id
        self.comment_text = comment_text
    }
}

/// Request model for fetching info about a specific photo.
public struct FlickrInfoRequest: Sendable {
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
public struct FlickrCommentsRequest: Sendable {
    public let photo_id: String

    public init(photo_id: String) {
        self.photo_id = photo_id
    }
}

// Internal decode wrappers for `flickr.photos.comments.getList`.
// The response nests the comment array at response.comments.comment,
// requiring two struct layers. `comment` is optional because a photo
// with no comments returns {"comments": {}} — the key is absent entirely.
struct FlickrCommentsResponse: Decodable {
    let comments: CommentInfo
}

struct CommentInfo: Decodable {
    let comment: [Comment]?
}

struct Comment: Decodable {
    let content: String

    // Flickr's JSON API uses "_content" for comment text — a legacy convention
    // carried over from the XML API, where text nodes were represented as
    // {"_content": "text"} in the JSON serialisation. CodingKeys maps the
    // wire name to the Swift-idiomatic `content` property. This mapping must
    // not be removed or reverted to "_content", as that would expose the
    // legacy wire name in the public-facing model.
    private enum CodingKeys: String, CodingKey {
        case content = "_content"
    }
}

