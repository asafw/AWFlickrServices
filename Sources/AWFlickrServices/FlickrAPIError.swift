//
//  FlickrAPIError.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

public enum AWFlickrAPIError: Error, Equatable {
    case parsingError
    case networkError
    /// Flickr returned HTTP 200 with `{"stat":"fail","code":...,"message":...}`.
    /// Distinct from a network failure — the server responded but rejected the request.
    case apiError(code: Int, message: String)
}
