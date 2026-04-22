//
//  FlickrService.swift
//
//
//  Created by Asaf Weinberg on 22/4/26.
//

/// A concrete service type that conforms to both `FlickrPhotosProtocol` and
/// `FlickrOAuthProtocol`.
///
/// Use `FlickrService` when you want a ready-made object without defining your
/// own conforming type:
///
/// ```swift
/// // SwiftUI
/// @State private var service = FlickrService()
///
/// // UIKit / general
/// let service = FlickrService()
/// let photos = try await service.getPhotos(apiKey: key, photosRequest: request)
/// ```
///
/// All behaviour is provided by the protocol extension default implementations.
public final class FlickrService: FlickrPhotosProtocol, FlickrOAuthProtocol {}
