//
//  FlickrModels.swift
//
//  
//  Created by Asaf Weinberg on 7/2/20.
//

public struct FlickrPhoto: Decodable {
    public let id: String
    let owner: String?
    public let secret: String
    let server: String
    let farm: Int
    public let title: String
    
    public func thumbnailPhotoURLString() -> String {
        return String(format: FlickrEndpoints().thumbnailPhotoUrlTemplate, String(farm), server, id, secret)
    }
    
    public func largePhotoURLString() -> String {
        return String(format: FlickrEndpoints().largePhotoUrlTemplate, String(farm), server, id, secret)
    }
}

struct FlickrPhotos: Decodable {
    let page: Int?
    let pages: Int?
    let perpage: Int?
    let total: String?
    let photo: [FlickrPhoto]
}

struct FlickrPhotosResponse: Decodable {
    let photos: FlickrPhotos
}

public struct FlickrPhotosRequest: Encodable {
    public let text: String
    public let page: String
    public let per_page: String
    
    public init(text: String, page: String, per_page: String) {
        self.text = text
        self.page = page
        self.per_page = per_page
    }
}

public struct FlickrFaveRequest: Encodable {
    public let photo_id: String
    
    public init(photo_id: String) {
        self.photo_id = photo_id
    }
}

public struct FlickrCommentRequest: Encodable {
    public let photo_id: String
    public let comment_text: String
    
    public init(photo_id: String, comment_text: String) {
        self.photo_id = photo_id
        self.comment_text = comment_text
    }
}

public struct FlickrInfoRequest: Encodable {
    public let photo_id: String
    public let secret: String
    
    public init(photo_id: String, secret: String) {
        self.photo_id = photo_id
        self.secret = secret
    }
}

public struct FlickrInfoResponse: Decodable {
    public let photo: PhotoInfo
}

public struct PhotoInfo: Decodable {
    public let owner: Owner
    public let dates: Dates
    public let views: String
}

public struct Owner: Decodable {
    public let realname: String
    public let location: String?
}

public struct Dates: Decodable {
    public let taken: String
}

public struct FlickrCommentsRequest: Encodable {
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
    let _content: String //Note underscore is not standard
}

