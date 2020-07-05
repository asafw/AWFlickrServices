//
//  FlickrAPIError.swift
//  
//
//  Created by Asaf Weinberg on 7/2/20.
//

enum FlickrAPIError: Error {
    case parsingError
    case networkError
    case downloadImageError
    case missingDataError
}
