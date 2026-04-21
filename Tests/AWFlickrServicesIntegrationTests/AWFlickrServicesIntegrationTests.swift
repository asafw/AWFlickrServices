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

private let apiKey: String? = {
    // 1. Shell env var (works for swift test on macOS CLI)
    if let v = ProcessInfo.processInfo.environment["FLICKR_API_KEY"], !v.isEmpty { return v }
    // 2. Temp file — write key here to unblock xcodebuild's sandboxed test runner:
    //    echo "your_key" > /tmp/flickr_api_key
    if let v = try? String(contentsOfFile: "/tmp/flickr_api_key", encoding: .utf8) {
        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
    }
    return nil
}()

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

    // MARK: - Parameter wiring

    /// Validates that `per_page` is actually sent and honoured by the API.
    func testPerPageCountIsRespected() throws {
        let key = try requireAPIKey()
        let expectation = expectation(description: "search completes")
        var photos: [FlickrPhoto] = []

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 3)
        ) { result in
            if case .success(let p) = result { photos = p }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertEqual(photos.count, 3, "per_page: 3 should yield exactly 3 photos")
    }

    /// Validates that `page` is sent and that successive pages return distinct photo IDs.
    func testPaginationReturnsDistinctPhotos() throws {
        let key = try requireAPIKey()
        let exp1 = expectation(description: "page 1")
        let exp2 = expectation(description: "page 2")
        var page1IDs: Set<String> = []
        var page2IDs: Set<String> = []

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "nature", page: 1, per_page: 5)
        ) { result in
            if case .success(let photos) = result { page1IDs = Set(photos.map(\.id)) }
            exp1.fulfill()
        }

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "nature", page: 2, per_page: 5)
        ) { result in
            if case .success(let photos) = result { page2IDs = Set(photos.map(\.id)) }
            exp2.fulfill()
        }

        wait(for: [exp1, exp2], timeout: 10)
        XCTAssertFalse(page1IDs.isEmpty, "Page 1 must have results")
        XCTAssertFalse(page2IDs.isEmpty, "Page 2 must have results")
        XCTAssertTrue(
            page1IDs.isDisjoint(with: page2IDs),
            "Page 1 and page 2 should contain distinct photo IDs"
        )
    }

    /// Validates RFC 3986 encoding of spaces in search terms end-to-end against the real API.
    func testSearchTermWithSpacesDecodes() throws {
        let key = try requireAPIKey()
        let expectation = expectation(description: "search completes")
        var photos: [FlickrPhoto] = []

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "golden gate bridge", page: 1, per_page: 3)
        ) { result in
            if case .success(let p) = result { photos = p }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        XCTAssertFalse(photos.isEmpty, "Search for 'golden gate bridge' (with spaces) should return photos")
        print("✅ Space-encoded search OK — \(photos.count) result(s)")
    }

    // MARK: - Error paths

    /// Validates that an invalid key yields `FlickrAPIError.apiError` — not a crash, hang,
    /// or raw DecodingError. Flickr returns HTTP 200 with `{"stat":"fail",...}` for bad keys,
    /// so this also validates that `FlickrAPIRepository` inspects `stat` before decoding.
    func testInvalidAPIKeyReturnsAPIError() throws {
        try XCTSkipIf(apiKey == nil || apiKey!.isEmpty, "Set FLICKR_API_KEY to run integration tests")
        let expectation = expectation(description: "search completes")
        var result: Result<[FlickrPhoto], Error>?

        repository.getPhotos(
            apiKey: "000000000000000000000000deadbeef",
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        ) { r in
            result = r
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        switch result! {
        case .success:
            XCTFail("Expected failure for an invalid API key")
        case .failure(let error):
            guard let apiError = error as? FlickrAPIError,
                  case .apiError(let code, let message) = apiError else {
                XCTFail("Expected FlickrAPIError.apiError, got \(type(of: error)): \(error)")
                return
            }
            print("✅ Invalid key correctly yielded .apiError(code: \(code), message: \"\(message)\")")
        }
    }

    /// Validates that requesting a page far beyond total results doesn't crash or error —
    /// Flickr silently clamps to the last valid page and returns results.
    func testPageBeyondTotalDoesNotError() throws {
        let key = try requireAPIKey()
        let expectation = expectation(description: "search completes")
        var didFail = false

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 99_999, per_page: 5)
        ) { result in
            if case .failure = result { didFail = true }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
        // Flickr clamps to the last valid page and still returns results — never an error
        XCTAssertFalse(didFail, "Page-beyond-total should complete with success, not failure")
    }

    // MARK: - CDN / model completeness

    /// Validates that `largePhotoURLString()` resolves and returns non-empty data.
    func testLargePhotoURLResolves() throws {
        let key = try requireAPIKey()
        let searchExp = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExp.fulfill()
        }
        wait(for: [searchExp], timeout: 10)
        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        let largeURL = URL(string: photo.largePhotoURLString())!
        let downloadExp = expectation(description: "large download done")
        var downloadResult: Result<Data, Error>?

        repository.downloadImageData(from: largeURL) { result in
            downloadResult = result
            downloadExp.fulfill()
        }
        wait(for: [downloadExp], timeout: 15)

        switch downloadResult! {
        case .success(let data):
            XCTAssertFalse(data.isEmpty, "Large photo download must not be empty")
            print("✅ Large CDN URL OK — \(data.count) bytes: \(largeURL)")
        case .failure(let error):
            XCTFail("Large photo URL failed: \(largeURL)\nError: \(error)")
        }
    }

    /// Validates that downloaded image data starts with the JPEG magic bytes FF D8 FF,
    /// confirming the server actually returned an image and not an HTML error page.
    func testDownloadedThumbnailIsJPEG() throws {
        let key = try requireAPIKey()
        let searchExp = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExp.fulfill()
        }
        wait(for: [searchExp], timeout: 10)
        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        let url = URL(string: photo.thumbnailPhotoURLString())!
        let downloadExp = expectation(description: "download done")
        var data: Data?

        repository.downloadImageData(from: url) { result in
            if case .success(let d) = result { data = d }
            downloadExp.fulfill()
        }
        wait(for: [downloadExp], timeout: 10)

        guard let bytes = data, bytes.count >= 3 else {
            XCTFail("No data returned for thumbnail URL"); return
        }
        let magic = [bytes[0], bytes[1], bytes[2]]
        XCTAssertEqual(
            magic, [0xFF, 0xD8, 0xFF],
            "Expected JPEG magic bytes FF D8 FF — got \(magic.map { String(format: "%02X", $0) }.joined(separator: " "))"
        )
        print("✅ Thumbnail is valid JPEG (\(bytes.count) bytes)")
    }

    /// Validates that `FlickrInfoResponse.photo.views` can be parsed as an Int
    /// (it arrives as a JSON string but must always be numeric).
    func testInfoViewsIsNumeric() throws {
        let key = try requireAPIKey()
        let searchExp = expectation(description: "search done")
        var firstPhoto: FlickrPhoto?

        repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "architecture", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { firstPhoto = photos.first }
            searchExp.fulfill()
        }
        wait(for: [searchExp], timeout: 10)
        guard let photo = firstPhoto else { XCTFail("No photo returned"); return }

        let infoExp = expectation(description: "getInfo done")
        var infoResult: Result<FlickrInfoResponse, Error>?

        repository.getInfo(
            apiKey: key,
            infoRequest: FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        ) { result in
            infoResult = result
            infoExp.fulfill()
        }
        wait(for: [infoExp], timeout: 10)

        switch infoResult! {
        case .success(let info):
            let parsedViews = Int(info.photo.views)
            XCTAssertNotNil(parsedViews, "views '\(info.photo.views)' must be parseable as Int")
            print("✅ views is numeric: \(info.photo.views)")
        case .failure(let error):
            XCTFail("getInfo failed: \(error)")
        }
    }

    // MARK: - Concurrency

    /// Fires 3 searches concurrently and verifies all complete without crash or data corruption.
    func testConcurrentSearchesCompleteWithoutCrash() throws {
        let key = try requireAPIKey()
        let terms = ["landscape", "portrait", "architecture"]
        var expectations: [XCTestExpectation] = []
        var results: [String: Int] = [:]
        let lock = NSLock()

        for term in terms {
            let exp = expectation(description: "\(term) done")
            expectations.append(exp)
            DispatchQueue.global().async {
                self.repository.getPhotos(
                    apiKey: key,
                    photosRequest: FlickrPhotosRequest(text: term, page: 1, per_page: 3)
                ) { result in
                    if case .success(let photos) = result {
                        lock.lock()
                        results[term] = photos.count
                        lock.unlock()
                    }
                    exp.fulfill()
                }
            }
        }

        wait(for: expectations, timeout: 15)
        XCTAssertEqual(results.count, 3, "All 3 concurrent searches must complete")
        for term in terms {
            XCTAssertEqual(results[term], 3, "'\(term)' search should return 3 photos")
        }
        print("✅ Concurrent searches OK: \(results)")
    }
}
