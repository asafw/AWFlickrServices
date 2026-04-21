/// AWFlickrServices — Live Integration Tests
///
/// These tests make real HTTP calls to the Flickr API to validate that:
///   1. The JSON response shapes still match the Swift models
///   2. Photo CDN URLs resolve (farm subdomain vs live.staticflickr.com)
///   3. `downloadImageData` returns non-empty Data
///
/// **Run locally only — never in CI.**
///
/// Usage:
///   export FLICKR_API_KEY="your_api_key_here"
///   xcodebuild -scheme AWFlickrServices \
///     -destination "platform=iOS Simulator,name=iPhone 16" \
///     -only-testing:AWFlickrServicesIntegrationTests test
///
/// Get a free API key at: https://www.flickr.com/services/api/misc.api_keys.html

import XCTest
@testable import AWFlickrServices

private let apiKey: String? = ProcessInfo.processInfo.environment["FLICKR_API_KEY"]

final class FlickrSearchIntegrationTests: XCTestCase {

    private var repository: FlickrAPIRepository!

    override func setUp() {
        super.setUp()
        repository = FlickrAPIRepository()
    }

    // MARK: - Helpers

    private func requireAPIKey(file: StaticString = #file, line: UInt = #line) throws -> String {
        try XCTSkipIf(
            apiKey == nil || apiKey!.isEmpty,
            "Set FLICKR_API_KEY environment variable to run integration tests"
        )
        return apiKey!
    }

    // MARK: - Search

    func testSearchReturnsPhotos() throws {
        let key = try requireAPIKey()
        let expectation = expectation(description: "search completes")
        var result: Result<[FlickrPhoto], Error>?

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 5)
        ) { r in
            result = r
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        switch result! {
        case .success(let photos):
            XCTAssertFalse(photos.isEmpty, "Search for 'landscape' should return at least one photo")
            let first = photos[0]
            XCTAssertFalse(first.id.isEmpty, "Photo id must not be empty")
            XCTAssertFalse(first.secret.isEmpty, "Photo secret must not be empty")
            XCTAssertFalse(first.server.isEmpty, "Photo server must not be empty")
            print("📸 First photo: id=\(first.id) server=\(first.server) farm=\(first.farm)")
            print("   thumbnail: \(first.thumbnailPhotoURLString())")
            print("   large:     \(first.largePhotoURLString())")
        case .failure(let error):
            XCTFail("Search failed: \(error)")
        }
    }

    func testSearchReturnsDecodedTitleAndOwner() throws {
        let key = try requireAPIKey()
        let expectation = expectation(description: "search completes")
        var photos: [FlickrPhoto] = []

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "sunset", page: 1, per_page: 3)
        ) { result in
            if case .success(let p) = result { photos = p }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertFalse(photos.isEmpty, "Expected photos from 'sunset' search")
        // owner is optional (search results may omit it unless extras=owner is added)
        // just verify the field decodes without crashing
        print("✅ Decoded \(photos.count) photo(s) — first title: '\(photos.first?.title ?? "(none)")'")
    }

    // MARK: - Photo CDN URL validation

    func testFarmURLResolves() throws {
        let key = try requireAPIKey()
        let searchExpectation = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExpectation.fulfill()
        }
        wait(for: [searchExpectation], timeout: 10)

        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        let thumbnailURL = URL(string: photo.thumbnailPhotoURLString())!
        let downloadExpectation = expectation(description: "thumbnail downloaded")
        var downloadResult: Result<Data, Error>?

        repository.downloadImageData(from: thumbnailURL) { result in
            downloadResult = result
            downloadExpectation.fulfill()
        }
        wait(for: [downloadExpectation], timeout: 10)

        switch downloadResult! {
        case .success(let data):
            XCTAssertFalse(data.isEmpty, "Downloaded image data must not be empty")
            print("✅ Farm CDN URL resolved — \(data.count) bytes: \(thumbnailURL)")
        case .failure(let error):
            // This is the canary — if farm URLs are dead, update FlickrEndpoints templates
            XCTFail("""
                ⚠️  Farm CDN URL FAILED: \(thumbnailURL)
                Flickr may have migrated to live.staticflickr.com.
                Update FlickrEndpoints.thumbnailPhotoUrlTemplate / largePhotoUrlTemplate.
                Error: \(error)
                """)
        }
    }

    // MARK: - getInfo

    func testGetInfoDecodesResponse() throws {
        let key = try requireAPIKey()

        // Step 1: get a real photo id
        let searchExpectation = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?
        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "architecture", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExpectation.fulfill()
        }
        wait(for: [searchExpectation], timeout: 10)
        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        // Step 2: fetch info for that photo
        let infoExpectation = expectation(description: "getInfo done")
        var infoResult: Result<FlickrInfoResponse, Error>?
        repository.getInfo(
            apiKey: key,
            infoRequest: FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        ) { result in
            infoResult = result
            infoExpectation.fulfill()
        }
        wait(for: [infoExpectation], timeout: 10)

        switch infoResult! {
        case .success(let info):
            XCTAssertFalse(info.photo.views.isEmpty, "views field must be present")
            XCTAssertFalse(info.photo.dates.taken.isEmpty, "taken date must be present")
            print("✅ getInfo OK — owner: '\(info.photo.owner.realname)', views: \(info.photo.views)")
        case .failure(let error):
            XCTFail("getInfo failed: \(error)")
        }
    }

    // MARK: - getComments

    func testGetCommentsDecodesWithoutCrashing() throws {
        let key = try requireAPIKey()

        let searchExpectation = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?
        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "popular", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExpectation.fulfill()
        }
        wait(for: [searchExpectation], timeout: 10)
        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        let commentsExpectation = expectation(description: "getComments done")
        var commentsResult: Result<[String], Error>?
        repository.getComments(
            apiKey: key,
            commentsRequest: FlickrCommentsRequest(photo_id: photo.id)
        ) { result in
            commentsResult = result
            commentsExpectation.fulfill()
        }
        wait(for: [commentsExpectation], timeout: 10)

        switch commentsResult! {
        case .success(let comments):
            // May be empty (no comments on this photo) — that's fine, just verify decoding
            print("✅ getComments OK — \(comments.count) comment(s)")
        case .failure(let error):
            XCTFail("getComments failed: \(error)")
        }
    }
}
