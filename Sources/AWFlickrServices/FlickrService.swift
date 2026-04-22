//
//  FlickrService.swift
//
//
//  Created by Asaf Weinberg on 22/4/26.
//

import Foundation

/// A concrete service type that conforms to both `FlickrPhotosProtocol` and
/// `FlickrOAuthProtocol`.
///
/// Use `FlickrService` when you want a ready-made object without defining your
/// own conforming type:
///
/// ```swift
/// // Default session (URLSession.shared)
/// let service = FlickrService()
///
/// // Custom session — e.g. inject a URLProtocol stub for tests
/// let service = FlickrService(urlSession: stubbedSession)
///
/// // Fetch photos
/// let photos = try await service.getPhotos(apiKey: key, photosRequest: request)
/// ```
///
/// All network behaviour is provided by the protocol extension default implementations
/// via the stored `urlSession`.
public final class FlickrService: FlickrPhotosProtocol, FlickrOAuthProtocol {

    /// The `URLSession` used by all default protocol method implementations.
    ///
    /// Defaults to `URLSession.shared`. Pass a custom session at init to
    /// intercept requests (e.g. with a `URLProtocol` stub) or to apply custom
    /// configuration such as timeouts or caching policies.
    public let urlSession: URLSession

    /// Creates a `FlickrService` with the given session.
    ///
    /// - Parameter urlSession: The session to use for all network requests.
    ///   Defaults to `URLSession.shared`.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
}
