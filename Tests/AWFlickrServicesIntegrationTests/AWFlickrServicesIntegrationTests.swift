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
///     -destination "platform=macOS" \
///     -only-testing:AWFlickrServicesIntegrationTests test
///
/// Get a free API key at: https://www.flickr.com/services/api/misc.api_keys.html

import XCTest
@testable import AWFlickrServices

/// Reads a credential from an env var or a /tmp file of the same name.
private func readCredential(_ envName: String) -> String? {
    if let v = ProcessInfo.processInfo.environment[envName], !v.isEmpty { return v }
    let fileName = envName.lowercased().replacingOccurrences(of: "_", with: "_")
    if let v = try? String(contentsOfFile: "/tmp/\(fileName)", encoding: .utf8) {
        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
    }
    return nil
}

private let apiKey: String? = readCredential("FLICKR_API_KEY")

final class FlickrSearchIntegrationTests: XCTestCase {

    private var repository: FlickrAPIService!

    override func setUp() {
        super.setUp()
        repository = FlickrAPIService()
    }

    // MARK: - Helpers

    private func requireAPIKey(file: StaticString = #file, line: UInt = #line) throws -> String {
        try XCTSkipIf(
            apiKey == nil || apiKey!.isEmpty,
            "Set FLICKR_API_KEY environment variable (or write to /tmp/flickr_api_key) to run integration tests",
            file: file, line: line
        )
        return apiKey!
    }

    private func requireCredential(
        _ name: String,
        hint: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> String {
        let value = readCredential(name)
        try XCTSkipIf(
            value == nil || value!.isEmpty,
            "Set \(name) env var or write to /tmp/\(name.lowercased()) to run this test (\(hint))",
            file: file, line: line
        )
        return value!
    }

    // MARK: - Search

    func testSearchReturnsPhotos() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 5)
        )
        XCTAssertFalse(photos.isEmpty, "Search for 'landscape' should return at least one photo")
        let first = photos[0]
        XCTAssertFalse(first.id.isEmpty, "Photo id must not be empty")
        XCTAssertFalse(first.secret.isEmpty, "Photo secret must not be empty")
        XCTAssertFalse(first.server.isEmpty, "Photo server must not be empty")
        print("📸 First photo: id=\(first.id) server=\(first.server) farm=\(first.farm)")
        print("   thumbnail: \(first.thumbnailPhotoURLString())")
        print("   large:     \(first.largePhotoURLString())")
    }

    func testSearchReturnsDecodedTitleAndOwner() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "sunset", page: 1, per_page: 3)
        )
        XCTAssertFalse(photos.isEmpty, "Expected photos from 'sunset' search")
        print("✅ Decoded \(photos.count) photo(s) — first title: '\(photos.first?.title ?? "(none)")'")
    }

    // MARK: - Photo CDN URL validation

    func testFarmURLResolves() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let thumbnailURL = URL(string: photo.thumbnailPhotoURLString())!
        let data = try await repository.downloadImageData(from: thumbnailURL)
        XCTAssertFalse(data.isEmpty, "Downloaded image data must not be empty")
        print("✅ Farm CDN URL resolved — \(data.count) bytes: \(thumbnailURL)")
    }

    // MARK: - getInfo

    func testGetInfoDecodesResponse() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "architecture", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let info = try await repository.getInfo(
            apiKey: key,
            infoRequest: FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        )
        XCTAssertFalse(info.photo.views.isEmpty, "views field must be present")
        XCTAssertFalse(info.photo.dates.taken.isEmpty, "taken date must be present")
        print("✅ getInfo OK — owner: '\(info.photo.owner.realname)', views: \(info.photo.views)")
    }

    // MARK: - getComments

    func testGetCommentsDecodesWithoutCrashing() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "popular", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let comments = try await repository.getComments(
            apiKey: key,
            commentsRequest: FlickrCommentsRequest(photo_id: photo.id)
        )
        // May be empty (no comments on this photo) — that's fine, just verify decoding
        print("✅ getComments OK — \(comments.count) comment(s)")
    }

    // MARK: - Parameter wiring

    func testPerPageCountIsRespected() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 3)
        )
        XCTAssertEqual(photos.count, 3, "per_page: 3 should yield exactly 3 photos")
    }

    func testPaginationReturnsDistinctPhotos() async throws {
        let key = try requireAPIKey()

        async let page1Photos = repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "nature", page: 1, per_page: 5)
        )
        async let page2Photos = repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "nature", page: 2, per_page: 5)
        )
        let (p1, p2) = try await (page1Photos, page2Photos)
        let page1IDs = Set(p1.map(\.id))
        let page2IDs = Set(p2.map(\.id))
        XCTAssertFalse(page1IDs.isEmpty, "Page 1 must have results")
        XCTAssertFalse(page2IDs.isEmpty, "Page 2 must have results")
        XCTAssertTrue(
            page1IDs.isDisjoint(with: page2IDs),
            "Page 1 and page 2 should contain distinct photo IDs"
        )
    }

    func testSearchTermWithSpacesDecodes() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "golden gate bridge", page: 1, per_page: 3)
        )
        XCTAssertFalse(photos.isEmpty, "Search for 'golden gate bridge' (with spaces) should return photos")
        print("✅ Space-encoded search OK — \(photos.count) result(s)")
    }

    // MARK: - Error paths

    func testInvalidAPIKeyReturnsAPIError() async throws {
        try XCTSkipIf(apiKey == nil || apiKey!.isEmpty, "Set FLICKR_API_KEY to run integration tests")

        do {
            _ = try await repository.getPhotos(
                apiKey: "000000000000000000000000deadbeef",
                photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
            )
            XCTFail("Expected failure for an invalid API key")
        } catch let apiError as FlickrAPIError {
            guard case .apiError(let code, let message) = apiError else {
                XCTFail("Expected .apiError, got \(apiError)")
                return
            }
            print("✅ Invalid key correctly yielded .apiError(code: \(code), message: \"\(message)\")")
        }
    }

    func testPageBeyondTotalDoesNotError() async throws {
        let key = try requireAPIKey()

        // Flickr clamps to the last valid page and still returns results — never an error
        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 99_999, per_page: 5)
        )
        _ = photos // Completion without throw proves the behaviour
        print("✅ Page-beyond-total completed without error")
    }

    // MARK: - CDN / model completeness

    func testLargePhotoURLResolves() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let largeURL = URL(string: photo.largePhotoURLString())!
        let data = try await repository.downloadImageData(from: largeURL)
        XCTAssertFalse(data.isEmpty, "Large photo download must not be empty")
        print("✅ Large CDN URL OK — \(data.count) bytes: \(largeURL)")
    }

    func testDownloadedThumbnailIsJPEG() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let url = URL(string: photo.thumbnailPhotoURLString())!
        let data = try await repository.downloadImageData(from: url)

        guard data.count >= 3 else {
            XCTFail("No data returned for thumbnail URL"); return
        }
        let magic = [data[0], data[1], data[2]]
        XCTAssertEqual(
            magic, [0xFF, 0xD8, 0xFF],
            "Expected JPEG magic bytes FF D8 FF — got \(magic.map { String(format: "%02X", $0) }.joined(separator: " "))"
        )
        print("✅ Thumbnail is valid JPEG (\(data.count) bytes)")
    }

    func testInfoViewsIsNumeric() async throws {
        let key = try requireAPIKey()

        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "architecture", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo returned"); return }

        let info = try await repository.getInfo(
            apiKey: key,
            infoRequest: FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        )
        let parsedViews = Int(info.photo.views)
        XCTAssertNotNil(parsedViews, "views '\(info.photo.views)' must be parseable as Int")
        print("✅ views is numeric: \(info.photo.views)")
    }

    // MARK: - Concurrency

    func testConcurrentSearchesCompleteWithoutCrash() async throws {
        let key = try requireAPIKey()
        let terms = ["landscape", "portrait", "architecture"]

        // Fire 3 searches concurrently using async let
        async let s1 = repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: terms[0], page: 1, per_page: 3)
        )
        async let s2 = repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: terms[1], page: 1, per_page: 3)
        )
        async let s3 = repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: terms[2], page: 1, per_page: 3)
        )
        let (r1, r2, r3) = try await (s1, s2, s3)
        let results = [terms[0]: r1.count, terms[1]: r2.count, terms[2]: r3.count]
        for term in terms {
            XCTAssertEqual(results[term], 3, "'\(term)' search should return 3 photos")
        }
        print("✅ Concurrent searches OK: \(results)")
    }
}

// MARK: - Live OAuth 1.0a signing tests

/// Tests that verify the HMAC-SHA1 signing chain works end-to-end against the real Flickr servers.
///
/// Credentials required (each as env var or /tmp file):
///   FLICKR_API_KEY    — public key   (required for all tests)
///   FLICKR_API_SECRET — shared secret (required for all tests in this suite)
///   FLICKR_OAUTH_TOKEN        — user access token (required for fave/unfave/comment)
///   FLICKR_OAUTH_TOKEN_SECRET — user token secret (required for fave/unfave/comment)
///
/// Write credentials:
///   echo "your_secret"       > /tmp/flickr_api_secret
///   echo "your_token"        > /tmp/flickr_oauth_token
///   echo "your_token_secret" > /tmp/flickr_oauth_token_secret
final class FlickrOAuthIntegrationTests: XCTestCase {

    private var repository: FlickrAPIService!

    override func setUp() {
        super.setUp()
        repository = FlickrAPIService()
    }

    // MARK: - Helpers

    private func requireKey(file: StaticString = #file, line: UInt = #line) throws -> String {
        let v = readCredential("FLICKR_API_KEY")
        try XCTSkipIf(v == nil || v!.isEmpty,
            "Write your API key to /tmp/flickr_api_key to run OAuth integration tests",
            file: file, line: line)
        return v!
    }

    private func requireSecret(file: StaticString = #file, line: UInt = #line) throws -> String {
        let v = readCredential("FLICKR_API_SECRET")
        try XCTSkipIf(v == nil || v!.isEmpty,
            "Write your API secret to /tmp/flickr_api_secret to run OAuth signing tests",
            file: file, line: line)
        return v!
    }

    private func requireOAuthToken(file: StaticString = #file, line: UInt = #line) throws -> (token: String, secret: String) {
        let tok = readCredential("FLICKR_OAUTH_TOKEN")
        let sec = readCredential("FLICKR_OAUTH_TOKEN_SECRET")
        try XCTSkipIf(tok == nil || sec == nil,
            "Write token to /tmp/flickr_oauth_token and secret to /tmp/flickr_oauth_token_secret",
            file: file, line: line)
        return (tok!, sec!)
    }

    // MARK: - getRequestToken (validates HMAC-SHA1 signing end-to-end)

    func testGetRequestTokenSigningIsAcceptedByFlickr() async throws {
        let key    = try requireKey()
        let secret = try requireSecret()

        let token = try await repository.getRequestToken(
            apiKey: key,
            apiSecret: secret,
            callbackUrlString: "myapp://oauth"
        )
        XCTAssertEqual(
            token.oauth_callback_confirmed, "true",
            "oauth_callback_confirmed should be 'true' — mismatch means signing key or base string is wrong"
        )
        XCTAssertFalse(token.oauth_token.isEmpty, "Request token must be non-empty")
        XCTAssertFalse(token.oauth_token_secret.isEmpty, "Request token secret must be non-empty")
        print("✅ OAuth request token accepted — token: \(token.oauth_token.prefix(10))...")
    }

    // MARK: - Fave / unfave (validates signed POST with user credentials)

    func testFaveAndUnfaveRoundTrip() async throws {
        let key           = try requireKey()
        let secret        = try requireSecret()
        let (token, tSec) = try requireOAuthToken()

        // Step 1: find a photo to fave
        let photos = try await repository.getPhotos(
            apiKey: key,
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        )
        guard let photo = photos.first else { XCTFail("No photo to fave"); return }

        // Step 2: fave
        do {
            try await repository.fave(
                apiKey: key, apiSecret: secret,
                oauthToken: token, oauthTokenSecret: tSec,
                faveRequest: FlickrFaveRequest(photo_id: photo.id)
            )
            print("✅ fave succeeded for photo \(photo.id)")
        } catch let error as FlickrAPIError {
            if case .apiError(let code, _) = error, code == 3 {
                print("ℹ️  Photo already faved (code 3) — still proves signing works")
            } else {
                XCTFail("fave failed: \(error)")
                return
            }
        }

        // Step 3: unfave (clean up)
        try await repository.unfave(
            apiKey: key, apiSecret: secret,
            oauthToken: token, oauthTokenSecret: tSec,
            faveRequest: FlickrFaveRequest(photo_id: photo.id)
        )
        print("✅ unfave succeeded — fave/unfave round trip complete")
    }
}
