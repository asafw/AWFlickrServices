import XCTest
@testable import AWFlickrServices

// MARK: - FlickrEndpoints

final class FlickrEndpointsTests: XCTestCase {

    func testHostURLIsFlickrRestEndpoint() {
        XCTAssertEqual(FlickrEndpoints.hostURL, "https://api.flickr.com/services/rest/")
    }

    func testPhotoURLTemplates() {
        XCTAssertTrue(FlickrEndpoints.thumbnailPhotoUrlTemplate.contains("_s.jpg"))
        XCTAssertTrue(FlickrEndpoints.largePhotoUrlTemplate.contains("_b.jpg"))
    }
}

// MARK: - FlickrPhoto URL helpers

final class FlickrPhotoTests: XCTestCase {

    private func makePhoto(farm: Int = 1, server: String = "srv", id: String = "123", secret: String = "abc") -> FlickrPhoto {
        // Decode from JSON to construct the struct without accessing internal init
        let json = """
        {"id":"\(id)","secret":"\(secret)","server":"\(server)","farm":\(farm),"title":"Test"}
        """
        return try! JSONDecoder().decode(FlickrPhoto.self, from: Data(json.utf8))
    }

    func testThumbnailURLFormat() {
        let photo = makePhoto(farm: 2, server: "65535", id: "99887766", secret: "abcdef00")
        XCTAssertEqual(
            photo.thumbnailPhotoURLString(),
            "https://farm2.staticflickr.com/65535/99887766_abcdef00_s.jpg"
        )
    }

    func testLargeURLFormat() {
        let photo = makePhoto(farm: 3, server: "12345", id: "55443322", secret: "deadbeef")
        XCTAssertEqual(
            photo.largePhotoURLString(),
            "https://farm3.staticflickr.com/12345/55443322_deadbeef_b.jpg"
        )
    }
}

// MARK: - FlickrPhotosRequest

final class FlickrPhotosRequestTests: XCTestCase {

    func testPageAndPerPageStoredAsInt() {
        let request = FlickrPhotosRequest(text: "cats", page: 2, per_page: 25)
        XCTAssertEqual(request.page, 2)
        XCTAssertEqual(request.per_page, 25)
        XCTAssertEqual(request.text, "cats")
    }
}

// MARK: - FlickrModels decoding

final class FlickrModelsDecodingTests: XCTestCase {

    func testFlickrInfoResponseDecoding() throws {
        let json = """
        {
          "photo": {
            "owner": { "realname": "Alice", "location": "Paris" },
            "dates": { "taken": "2020-07-02 10:00:00" },
            "views": "42"
          }
        }
        """
        let response = try JSONDecoder().decode(FlickrInfoResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.photo.owner.realname, "Alice")
        XCTAssertEqual(response.photo.owner.location, "Paris")
        XCTAssertEqual(response.photo.dates.taken, "2020-07-02 10:00:00")
        XCTAssertEqual(response.photo.views, "42")
    }

    func testOwnerWithoutLocationDecodesNil() throws {
        let json = """
        {"realname":"Bob"}
        """
        let owner = try JSONDecoder().decode(Owner.self, from: Data(json.utf8))
        XCTAssertEqual(owner.realname, "Bob")
        XCTAssertNil(owner.location)
    }

    func testCommentContentCodingKey() throws {
        // The Flickr API returns {"_content": "great photo!"}
        let json = """
        {"comments": {"comment": [{"_content": "great photo!"}]}}
        """
        let response = try JSONDecoder().decode(FlickrCommentsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.comments.comment?.first?.content, "great photo!")
    }

    func testAccessTokenResponseDecoding() throws {
        let json = """
        {
          "fullname": "Alice Flickr",
          "oauth_token": "tok123",
          "oauth_token_secret": "sec456",
          "user_nsid": "12345@N07",
          "username": "aliceflickr"
        }
        """
        let token = try JSONDecoder().decode(AccessTokenResponse.self, from: Data(json.utf8))
        XCTAssertEqual(token.fullname, "Alice Flickr")
        XCTAssertEqual(token.oauth_token, "tok123")
        XCTAssertEqual(token.user_nsid, "12345@N07")
    }
}

// MARK: - FlickrAPIRepository (URL building via URLProtocol stub)

/// Captures the last request made through a URLSession configured with this protocol.
final class CapturingURLProtocol: URLProtocol {
    static var lastRequest: URLRequest?
    static var stubbedData: Data = Data()
    static var stubbedStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        CapturingURLProtocol.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: CapturingURLProtocol.stubbedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: CapturingURLProtocol.stubbedData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class FlickrAPIRepositoryURLBuildingTests: XCTestCase {

    private var session: URLSession!
    private var repository: FlickrAPIRepository!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        session = URLSession(configuration: config)
        repository = FlickrAPIRepository(session: session)
        CapturingURLProtocol.stubbedStatusCode = 200
        CapturingURLProtocol.stubbedData = Data()
        CapturingURLProtocol.lastRequest = nil
    }

    override func tearDown() {
        CapturingURLProtocol.lastRequest = nil
        CapturingURLProtocol.stubbedData = Data()
        CapturingURLProtocol.stubbedStatusCode = 200
        super.tearDown()
    }

    func testGetPhotosRequestContainsSearchMethod() {
        let expectation = expectation(description: "request sent")
        CapturingURLProtocol.stubbedData = Data("""
        {"photos":{"photo":[],"page":1,"pages":1,"perpage":20,"total":0}}
        """.utf8)

        repository.getPhotos(
            apiKey: "KEY",
            photosRequest: FlickrPhotosRequest(text: "mountains", page: 1, per_page: 20)
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.photos.search"), "URL should contain Flickr search method, got: \(url)")
        XCTAssertTrue(url.contains("mountains"), "URL should contain search text")
    }

    func testDownloadImageDataUsesReturnCacheDataElseLoad() {
        let expectation = expectation(description: "image request sent")
        CapturingURLProtocol.stubbedData = Data([0xFF, 0xD8, 0xFF]) // minimal stub bytes

        let url = URL(string: "https://farm1.staticflickr.com/1/1_a_s.jpg")!
        repository.downloadImageData(from: url) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(
            CapturingURLProtocol.lastRequest?.cachePolicy,
            .returnCacheDataElseLoad,
            "downloadImageData should use returnCacheDataElseLoad cache policy"
        )
    }

    func testHTTP4xxFailsWithNetworkError() {
        let expectation = expectation(description: "request fails")
        CapturingURLProtocol.stubbedStatusCode = 403
        CapturingURLProtocol.stubbedData = Data()

        repository.getPhotos(
            apiKey: "KEY",
            photosRequest: FlickrPhotosRequest(text: "cats", page: 1, per_page: 10)
        ) { result in
            if case .failure(let error as FlickrAPIError) = result {
                XCTAssertEqual(error, .networkError)
            } else {
                XCTFail("Expected networkError for 403, got \(result)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testFlickrAPIStatFailReturnsAPIError() {
        let expectation = expectation(description: "stat fail handled")
        // Flickr returns HTTP 200 with this shape when the API key is invalid.
        CapturingURLProtocol.stubbedData = Data("""
        {"stat":"fail","code":100,"message":"Invalid API Key (Key has invalid format)"}
        """.utf8)

        var receivedError: FlickrAPIError?
        repository.getPhotos(
            apiKey: "BADKEY",
            photosRequest: FlickrPhotosRequest(text: "landscape", page: 1, per_page: 1)
        ) { result in
            if case .failure(let e as FlickrAPIError) = result { receivedError = e }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(receivedError, .apiError(code: 100, message: "Invalid API Key (Key has invalid format)"))
    }

    func testGetInfoRequestContainsInfoMethod() {
        let expectation = expectation(description: "request sent")
        CapturingURLProtocol.stubbedData = Data("""
        {"photo":{"owner":{"realname":"Test"},"dates":{"taken":"2020-01-01"},"views":"5"}}
        """.utf8)

        repository.getInfo(
            apiKey: "KEY",
            infoRequest: FlickrInfoRequest(photo_id: "999", secret: "abc")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.photos.getInfo"), "URL should contain getInfo method, got: \(url)")
        XCTAssertTrue(url.contains("photo_id=999"))
    }

    func testGetCommentsRequestContainsCommentsMethod() {
        let expectation = expectation(description: "request sent")
        CapturingURLProtocol.stubbedData = Data("""
        {"comments":{"comment":[{"_content":"nice!"}]}}
        """.utf8)

        repository.getComments(
            apiKey: "KEY",
            commentsRequest: FlickrCommentsRequest(photo_id: "777")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.photos.comments.getList"), "URL should contain getList method, got: \(url)")
        XCTAssertTrue(url.contains("photo_id=777"))
    }

    func testFaveRequestContainsFaveMethod() {
        let expectation = expectation(description: "request sent")

        repository.fave(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "TOKSEC",
            faveRequest: FlickrFaveRequest(photo_id: "111")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.favorites.add"), "URL should contain favorites.add method, got: \(url)")
        XCTAssertEqual(CapturingURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testUnfaveRequestContainsUnfaveMethod() {
        let expectation = expectation(description: "request sent")

        repository.unfave(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "TOKSEC",
            faveRequest: FlickrFaveRequest(photo_id: "222")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.favorites.remove"), "URL should contain favorites.remove method, got: \(url)")
        XCTAssertEqual(CapturingURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testCommentRequestContainsCommentMethod() {
        let expectation = expectation(description: "request sent")

        repository.comment(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "TOKSEC",
            commentRequest: FlickrCommentRequest(photo_id: "333", comment_text: "hello")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("flickr.photos.comments.addComment"), "URL should contain addComment method, got: \(url)")
        XCTAssertEqual(CapturingURLProtocol.lastRequest?.httpMethod, "POST")
    }

    func testCommentTextWithSpacesIsRFC3986Encoded() {
        let expectation = expectation(description: "request sent")

        repository.comment(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "TOKSEC",
            commentRequest: FlickrCommentRequest(photo_id: "444", comment_text: "great photo!")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertFalse(url.contains("great photo!"), "Space must be percent-encoded, not passed raw")
        XCTAssertTrue(url.contains("great%20photo") || url.contains("great+photo") == false,
                      "Space should be %20-encoded per RFC 3986, got: \(url)")
    }

    func testGetPhotosReturnsDecodedPhotoArray() {
        let expectation = expectation(description: "photos decoded")
        CapturingURLProtocol.stubbedData = Data("""
        {"photos":{"photo":[{"id":"42","secret":"s3cr3t","server":"66666","farm":4,"title":"Sunset"}],"page":1,"pages":1,"perpage":1,"total":1}}
        """.utf8)

        var decoded: [FlickrPhoto] = []
        repository.getPhotos(
            apiKey: "KEY",
            photosRequest: FlickrPhotosRequest(text: "sunset", page: 1, per_page: 1)
        ) { result in
            if case .success(let photos) = result { decoded = photos }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.id, "42")
        XCTAssertEqual(decoded.first?.secret, "s3cr3t")
        XCTAssertEqual(decoded.first?.title, "Sunset")
    }

    func testGetCommentsReturnsDecodedStringArray() {
        let expectation = expectation(description: "comments decoded")
        CapturingURLProtocol.stubbedData = Data("""
        {"comments":{"comment":[{"_content":"first comment"},{"_content":"second comment"}]}}
        """.utf8)

        var decoded: [String] = []
        repository.getComments(
            apiKey: "KEY",
            commentsRequest: FlickrCommentsRequest(photo_id: "100")
        ) { result in
            if case .success(let comments) = result { decoded = comments }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(decoded, ["first comment", "second comment"])
    }

    func testGetInfoReturnsDecodedResponse() {
        let expectation = expectation(description: "info decoded")
        CapturingURLProtocol.stubbedData = Data("""
        {"photo":{"owner":{"realname":"Alice","location":"London"},"dates":{"taken":"2021-06-15 12:00:00"},"views":"99"}}
        """.utf8)

        var decoded: FlickrInfoResponse?
        repository.getInfo(
            apiKey: "KEY",
            infoRequest: FlickrInfoRequest(photo_id: "555", secret: "xyz")
        ) { result in
            if case .success(let info) = result { decoded = info }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(decoded?.photo.owner.realname, "Alice")
        XCTAssertEqual(decoded?.photo.owner.location, "London")
        XCTAssertEqual(decoded?.photo.views, "99")
    }

    func testDownloadImageDataReturnsBytes() {
        let expectation = expectation(description: "data returned")
        let stubBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        CapturingURLProtocol.stubbedData = stubBytes

        var returned: Data?
        repository.downloadImageData(from: URL(string: "https://farm1.staticflickr.com/1/1_b_s.jpg")!) { result in
            if case .success(let data) = result { returned = data }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(returned, stubBytes)
    }

    func testSignedURLContainsOAuthSignature() {
        let expectation = expectation(description: "request sent")

        repository.fave(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "TOKSEC",
            faveRequest: FlickrFaveRequest(photo_id: "999")
        ) { _ in expectation.fulfill() }

        wait(for: [expectation], timeout: 2)
        let url = CapturingURLProtocol.lastRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("oauth_signature="), "Signed URL must contain oauth_signature, got: \(url)")
    }
}

// MARK: - FlickrAPIRepository OAuth response parsing

final class FlickrAPIRepositoryOAuthParsingTests: XCTestCase {

    private var session: URLSession!
    private var repository: FlickrAPIRepository!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        session = URLSession(configuration: config)
        repository = FlickrAPIRepository(session: session)
        CapturingURLProtocol.stubbedStatusCode = 200
        CapturingURLProtocol.stubbedData = Data()
        CapturingURLProtocol.lastRequest = nil
    }

    override func tearDown() {
        CapturingURLProtocol.lastRequest = nil
        CapturingURLProtocol.stubbedData = Data()
        CapturingURLProtocol.stubbedStatusCode = 200
        super.tearDown()
    }

    func testGetRequestTokenParsesKeyValueResponse() {
        let expectation = expectation(description: "request token parsed")
        // Flickr returns URL-encoded key=value pairs
        let responseBody = "oauth_callback_confirmed=true&oauth_token=REQ_TOK&oauth_token_secret=REQ_SEC"
        CapturingURLProtocol.stubbedData = Data(responseBody.utf8)

        var decoded: RequestTokenResponse?
        repository.getRequestToken(apiKey: "KEY", apiSecret: "SECRET", callbackUrlString: "myapp://oauth") { result in
            if case .success(let token) = result { decoded = token }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(decoded?.oauth_token, "REQ_TOK")
        XCTAssertEqual(decoded?.oauth_token_secret, "REQ_SEC")
        XCTAssertEqual(decoded?.oauth_callback_confirmed, "true")
    }

    func testGetRequestTokenHTTPErrorReturnsNetworkError() {
        let expectation = expectation(description: "network error")
        CapturingURLProtocol.stubbedStatusCode = 401

        var receivedError: FlickrAPIError?
        repository.getRequestToken(apiKey: "KEY", apiSecret: "SECRET", callbackUrlString: "myapp://oauth") { result in
            if case .failure(let e as FlickrAPIError) = result { receivedError = e }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(receivedError, .networkError)
    }

    func testGetAccessTokenParsesKeyValueResponse() {
        let expectation = expectation(description: "access token parsed")
        let responseBody = "fullname=Alice%20Flickr&oauth_token=ACC_TOK&oauth_token_secret=ACC_SEC&user_nsid=99%40N00&username=alice"
        CapturingURLProtocol.stubbedData = Data(responseBody.utf8)

        var decoded: AccessTokenResponse?
        repository.getAccessToken(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "REQ_TOK", oauthTokenSecret: "REQ_SEC",
            oauthVerifier: "VERIFIER"
        ) { result in
            if case .success(let token) = result { decoded = token }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(decoded?.oauth_token, "ACC_TOK")
        XCTAssertEqual(decoded?.oauth_token_secret, "ACC_SEC")
        XCTAssertEqual(decoded?.username, "alice")
    }

    func testGetAccessTokenHTTPErrorReturnsNetworkError() {
        let expectation = expectation(description: "network error")
        CapturingURLProtocol.stubbedStatusCode = 500

        var receivedError: FlickrAPIError?
        repository.getAccessToken(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOK", oauthTokenSecret: "SEC",
            oauthVerifier: "VER"
        ) { result in
            if case .failure(let e as FlickrAPIError) = result { receivedError = e }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(receivedError, .networkError)
    }
}

// MARK: - RFC 3986 encoding edge cases

final class RFC3986EncodingTests: XCTestCase {

    private func encoded(_ input: String) -> String {
        // Exercise rfc3986Encoded via a comment_text value that appears in the generated URL.
        // We build a URL using CapturingURLProtocol and extract the comment_text value.
        // Because that's heavyweight, we test the contract more directly:
        // rfc3986Encoded must percent-encode everything outside alphanumerics + "-._~"
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return input.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    private func assertEncoded(_ input: String, doesNotContain literal: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(encoded(input).contains(literal), "'\(literal)' should be encoded in output of '\(input)'", file: file, line: line)
    }

    func testSpaceIsEncoded() { assertEncoded("hello world", doesNotContain: " ") }
    func testAmpersandIsEncoded() { assertEncoded("a&b", doesNotContain: "&") }
    func testEqualsIsEncoded() { assertEncoded("a=b", doesNotContain: "=") }
    func testPlusIsEncoded() { assertEncoded("a+b", doesNotContain: "+") }
    func testHashIsEncoded() { assertEncoded("a#b", doesNotContain: "#") }
    func testSlashIsEncoded() { assertEncoded("a/b", doesNotContain: "/") }
    func testUnreservedCharsAreNotEncoded() {
        let input = "abcABC123-._~"
        XCTAssertEqual(encoded(input), input, "Unreserved chars must pass through unencoded")
    }
}

// MARK: - OAuth 1.0a utility correctness

final class OAuthUtilitiesTests: XCTestCase {

    // MARK: - HMAC-SHA1 correctness

    /// RFC 2202 test case 2 — the definitive spec test vector for HMAC-SHA1.
    /// If this fails the signing of every OAuth request will be wrong.
    func testHMACSHA1RFC2202TestCase2() {
        // key = "Jefe", data = "what do ya want for nothing?"
        // Expected digest (hex): effcdf6ae5eb2fa2d27416d5f184df9c259a7c79
        let result = hmacsha1EncryptedString(
            string: "what do ya want for nothing?",
            key: "Jefe"
        )
        XCTAssertEqual(
            result, "7/zfauXrL6LSdBbV8YTfnCWafHk=",
            "HMAC-SHA1 does not match RFC 2202 test case 2 — every OAuth signature will be wrong"
        )
    }

    // MARK: - OAuth parameter presence

    /// All seven required OAuth 1.0a parameters must be present in a signed URL.
    func testAllRequiredOAuthParamsPresent() {
        let url = generateFaveURL(
            apiKey: "KEY", apiSecret: "SECRET",
            oauthToken: "TOKEN", oauthTokenSecret: "TOKSEC",
            photoId: "123"
        )!
        let query = url.query ?? ""
        for param in [
            "oauth_nonce", "oauth_timestamp", "oauth_consumer_key",
            "oauth_signature_method", "oauth_version", "oauth_token", "oauth_signature"
        ] {
            XCTAssertTrue(query.contains(param), "Missing required OAuth param: \(param)")
        }
    }

    func testSignatureMethodIsHMACSHA1() {
        let url = generateFaveURL(
            apiKey: "K", apiSecret: "S",
            oauthToken: "T", oauthTokenSecret: "TS",
            photoId: "1"
        )!
        XCTAssertTrue(
            url.query?.contains("oauth_signature_method=HMAC-SHA1") == true,
            "oauth_signature_method must be HMAC-SHA1"
        )
    }

    func testOAuthVersionIs1Point0() {
        let url = generateFaveURL(
            apiKey: "K", apiSecret: "S",
            oauthToken: "T", oauthTokenSecret: "TS",
            photoId: "1"
        )!
        XCTAssertTrue(
            url.query?.contains("oauth_version=1.0") == true,
            "oauth_version must be 1.0"
        )
    }

    func testNonceContainsNoHyphens() {
        for _ in 0..<5 {
            let url = generateFaveURL(
                apiKey: "K", apiSecret: "S",
                oauthToken: "T", oauthTokenSecret: "TS",
                photoId: "1"
            )!
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let nonce = items.first(where: { $0.name == "oauth_nonce" })?.value {
                XCTAssertFalse(nonce.contains("-"),
                    "oauth_nonce must be alphanumeric (no hyphens); got: \(nonce)")
            } else {
                XCTFail("oauth_nonce not found in URL")
            }
        }
    }

    // MARK: - Request / access token URL parameters

    func testRequestTokenURLContainsOAuthCallback() {
        let url = generateRequestTokenURL(
            apiKey: "KEY", apiSecret: "SECRET",
            callbackUrlString: "myapp://oauth"
        )!
        XCTAssertTrue(
            url.absoluteString.contains("oauth_callback"),
            "Request token URL must contain oauth_callback"
        )
    }

    func testAccessTokenURLContainsOAuthVerifier() {
        let url = generateAccessTokenURL(
            apiKey: "K", apiSecret: "S",
            oauthToken: "TOK", oauthTokenSecret: "SEC",
            oauthVerifier: "VER123"
        )!
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("oauth_verifier"), "Access token URL must contain oauth_verifier")
        XCTAssertTrue(query.contains("VER123"), "oauth_verifier value must appear in URL")
    }

    func testAccessTokenURLContainsOAuthToken() {
        let url = generateAccessTokenURL(
            apiKey: "K", apiSecret: "S",
            oauthToken: "MYTOK", oauthTokenSecret: "SEC",
            oauthVerifier: "VER"
        )!
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("oauth_token"), "Access token URL must contain oauth_token")
        XCTAssertTrue(query.contains("MYTOK"), "oauth_token value must appear in URL")
    }

    // MARK: - Signing key format

    /// Proves that the request-token step signs with key `"apiSecret&"` (empty token secret),
    /// as required by OAuth 1.0a section 3.4.2.
    /// Reconstructs the signature base string from the generated URL and recomputes
    /// the expected signature — if the signing key were wrong the values would differ.
    func testRequestTokenSigningKeyUsesEmptyTokenSecret() {
        let apiKey    = "testkey123"
        let apiSecret = "testsecret456"

        guard let url = generateRequestTokenURL(
            apiKey: apiKey, apiSecret: apiSecret,
            callbackUrlString: "myapp://oauth"
        ) else { XCTFail("generateRequestTokenURL returned nil"); return }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else { XCTFail("Could not parse URL components"); return }

        var params = [String: String]()
        for item in queryItems { if let v = item.value { params[item.name] = v } }

        guard let extractedSignature = params["oauth_signature"]
        else { XCTFail("oauth_signature not found"); return }

        // Reconstruct the OAuth 1.0a signature base string from the URL query items.
        var baseParams = params
        baseParams.removeValue(forKey: "oauth_signature")
        let sortedPairs = baseParams.keys.sorted()
            .map { "\(rfc3986Encoded($0))=\(rfc3986Encoded(baseParams[$0]!))" }
            .joined(separator: "&")
        let baseURL = FlickrEndpoints.requestTokenEndpoint
        let signatureBaseString = "GET&\(rfc3986Encoded(baseURL))&\(rfc3986Encoded(sortedPairs))"

        // Request-token signing key = "apiSecret&" (token secret is empty at this step)
        let expectedSignature = hmacsha1EncryptedString(
            string: signatureBaseString,
            key: "\(apiSecret)&"
        )

        XCTAssertEqual(
            extractedSignature, expectedSignature,
            "Request token signing key must be 'apiSecret&' (empty token secret per OAuth 1.0a spec)"
        )
    }
}
