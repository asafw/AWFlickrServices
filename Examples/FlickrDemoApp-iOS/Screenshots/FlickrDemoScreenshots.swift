import XCTest

final class FlickrDemoScreenshots: XCTestCase {

    private let apiKey = "3884ca4065efe9ed571d39eb1f022b56"
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Disable animations so the UI settles instantly.
        app.launchArguments += ["-UIAnimationDragCoefficient", "0"]
        // Inject live API key so DemoViewModel reads it from ProcessInfo.environment.
        app.launchEnvironment["FLICKR_API_KEY"] = apiKey
    }

    // MARK: - Helpers

    private func save(_ name: String) {
        let screenshot = app.screenshot()
        let att = XCTAttachment(screenshot: screenshot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        print("📸 \(name)")
    }

    // MARK: - Screenshots

    /// Capture the empty / unauthenticated state.
    func testEmptyState() throws {
        app.launch()
        _ = app.navigationBars["Flickr Demo"].waitForExistence(timeout: 5)
        save("ios_empty_state")
    }

    /// Capture the signed-in state (mock OAuth token).
    func testSignedInState() throws {
        app.launchArguments += ["-mockAuth"]
        app.launch()
        _ = app.navigationBars["Flickr Demo"].waitForExistence(timeout: 5)
        save("ios_signed_in")
    }

    /// Capture search results: MOCK_PHOTOS bypasses the network and immediately
    /// populates the grid with real Flickr photo data (no API call needed).
    func testSearchResults() throws {
        app.launchEnvironment["MOCK_PHOTOS"] = "1"
        app.launch()
        _ = app.navigationBars["Flickr Demo"].waitForExistence(timeout: 5)

        // Cells appear as soon as the photos array is non-empty (no image load needed).
        let firstPhoto = app.scrollViews.firstMatch.buttons.firstMatch
        XCTAssert(firstPhoto.waitForExistence(timeout: 5), "Mock photo cells did not appear")
        sleep(2) // let thumbnail images attempt to paint
        save("ios_search_results")
    }

    /// Capture photo detail view (unauthenticated).
    func testPhotoDetail() throws {
        app.launchEnvironment["MOCK_PHOTOS"] = "1"
        app.launch()
        _ = app.navigationBars["Flickr Demo"].waitForExistence(timeout: 5)

        let firstPhoto = app.scrollViews.firstMatch.buttons.firstMatch
        XCTAssert(firstPhoto.waitForExistence(timeout: 5), "Mock photo cells did not appear")
        firstPhoto.tap()
        sleep(3) // let detail view render
        save("ios_photo_detail")
    }

    /// Capture search results while authenticated (fave/comment controls visible in detail).
    func testAuthenticatedSearchResults() throws {
        app.launchArguments += ["-mockAuth"]
        app.launchEnvironment["MOCK_PHOTOS"] = "1"
        app.launch()
        _ = app.navigationBars["Flickr Demo"].waitForExistence(timeout: 5)

        let firstPhoto = app.scrollViews.firstMatch.buttons.firstMatch
        XCTAssert(firstPhoto.waitForExistence(timeout: 5), "Mock photo cells did not appear")
        sleep(2)
        save("ios_search_results_signed_in")

        firstPhoto.tap()
        sleep(3)
        save("ios_photo_detail_authenticated")
    }
}
