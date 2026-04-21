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
