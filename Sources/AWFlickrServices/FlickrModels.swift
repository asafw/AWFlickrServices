//
//  FlickrModels.swift
//
//  
//  Created by Asaf Weinberg on 7/2/20.
//

struct Photo: Decodable {
    let id: String
    let owner: String?
    let secret: String
    let server: String
    let farm: Int
    let title: String
    
    func thumbnailPhotoURLString() -> String {
        return String(format: FlickrEndpoints().thumbnailPhotoUrlTemplate, String(farm), server, id, secret)
    }
    
    func largePhotoURLString() -> String {
        return String(format: FlickrEndpoints().largePhotoUrlTemplate, String(farm), server, id, secret)
    }
}

struct Photos: Decodable {
    let page: Int?
    let pages: Int?
    let perpage: Int?
    let total: String?
    let photo: [Photo]
}

struct PhotosResponse: Decodable {
    let photos: Photos
}

struct PhotosRequest: Encodable {
    let text: String
    let page: String
    let per_page: String
}

struct FaveRequest: Encodable {
    let photo_id: String
}

struct CommentRequest: Encodable {
    let photo_id: String
    let comment_text: String
}

struct InfoRequest: Encodable {
    let photo_id: String
    let secret: String
}

struct InfoResponse: Decodable {
    let photo: PhotoInfo
}

struct PhotoInfo: Decodable {
    let owner: Owner
    let dates: Dates
    let views: String
}

struct Owner: Decodable {
    let realname: String
    let location: String?
}

struct Dates: Decodable {
    let taken: String
}

struct CommentsRequest: Encodable {
    let photo_id: String
}

struct CommentsResponse: Decodable {
    let comments: CommentInfo
}

struct CommentInfo: Decodable {
    let comment: [Comment]?
}

struct Comment: Decodable {
    let _content: String //Note underscore is not standard
}

