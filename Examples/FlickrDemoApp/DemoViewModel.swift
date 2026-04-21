// DemoViewModel.swift — Observable state connecting the UI to AWFlickrServices.

import CoreGraphics
import Foundation
import Combine
import ImageIO
import AWFlickrServices

/// Drives the demo UI. Conforms to FlickrPhotosProtocol and FlickrOAuthProtocol
/// so it can exercise the full public API surface of AWFlickrServices.
final class DemoViewModel: ObservableObject, FlickrPhotosProtocol, FlickrOAuthProtocol {

    // MARK: - Configuration

    /// Set via FLICKR_API_KEY env var, or paste into the in-app field.
    @Published var apiKey: String = ProcessInfo.processInfo.environment["FLICKR_API_KEY"] ?? ""
    /// Set via FLICKR_API_SECRET env var, or paste into the in-app field.
    @Published var apiSecret: String = ProcessInfo.processInfo.environment["FLICKR_API_SECRET"] ?? ""

    // MARK: - Auth state

    @Published var oauthToken: String = ""
    @Published var oauthTokenSecret: String = ""
    @Published var signedInAs: String? = nil
    @Published var isSigningIn: Bool = false
    @Published var authError: String? = nil

    var isAuthenticated: Bool { !oauthToken.isEmpty }

    private let presentationContext = PresentationContext()

    // MARK: - Search state

    @Published var searchText: String = ""
    @Published var photos: [FlickrPhoto] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    /// Set by MOCK_DETAIL seam — ContentView presents a detail sheet for the first photo.
    @Published var showScreenshotDetail: Bool = false

    #if DEBUG
    /// Pre-populated by MOCK_PHOTOS seam so PhotoDetailView skips network calls.
    var mockPhotoInfo: FlickrInfoResponse? = nil
    var mockPhotoComments: [String] = []
    #endif

    // MARK: - Init

    init() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments

        // UITest / screenshot seam: pass -mockAuth in launchArguments to pre-seed
        // a fake OAuth token so photo detail shows fave/comment controls.
        if args.contains("-mockAuth") {
            oauthToken       = "mock_token_for_screenshot"
            oauthTokenSecret = "mock_secret_for_screenshot"
            signedInAs       = "screenshot_user"
        }

        // Auto-search seam: set AUTO_SEARCH env var to a search term and the
        // app will populate searchText and trigger search after a short delay.
        // Used by screenshot UITests to avoid keyboard/button interaction issues.
        if let term = env["AUTO_SEARCH"], !term.isEmpty {
            searchText = term
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.search()
            }
        }

        // MOCK_PHOTOS seam: bypasses network entirely for screenshot tests.
        // Set MOCK_PHOTOS to any non-empty value to immediately populate photos
        // with real Flickr cat photo data (captured 2026-04).
        // MOCK_DETAIL seam: makes ContentView immediately present the detail sheet
        // for the first mock photo. Requires MOCK_PHOTOS to also be set.
        if env["MOCK_DETAIL"] != nil {
            showScreenshotDetail = true
        }

        if env["MOCK_PHOTOS"] != nil {
            searchText = "cat"
            let json = """
            [
              {"id":"55222618564","owner":"30052849@N07","secret":"716c1df7a1","server":"65535","farm":66,"title":"cat"},
              {"id":"55222591949","owner":"79923106@N02","secret":"bd26ff9016","server":"65535","farm":66,"title":"Street Cat"},
              {"id":"55222749215","owner":"79923106@N02","secret":"e867044cf4","server":"65535","farm":66,"title":"Street Cat"},
              {"id":"55222566619","owner":"48695801@N03","secret":"7fd2eca734","server":"65535","farm":66,"title":"Even big cats need to sleep."},
              {"id":"55222467178","owner":"87805257@N00","secret":"c55285bd69","server":"65535","farm":66,"title":"Papageno"},
              {"id":"55222300021","owner":"13441928@N04","secret":"94ec211701","server":"65535","farm":66,"title":"Lucy and John's cat"},
              {"id":"55221396282","owner":"201292385@N07","secret":"a8a8bc4ca0","server":"65535","farm":66,"title":"Redwing on Cat Tail"},
              {"id":"55222462643","owner":"201292385@N07","secret":"42c44117b7","server":"65535","farm":66,"title":"Redwing Talking"},
              {"id":"55222463073","owner":"201292385@N07","secret":"1daebab9cb","server":"65535","farm":66,"title":"Yellowhead Male"},
              {"id":"55222469308","owner":"201292385@N07","secret":"838e578fd9","server":"65535","farm":66,"title":"Redwing on Cat Tail 2"},
              {"id":"55222554474","owner":"201292385@N07","secret":"89a4cea6b5","server":"65535","farm":66,"title":"Yellowhead Eating"},
              {"id":"55222715780","owner":"201292385@N07","secret":"a3f9bc35e1","server":"65535","farm":66,"title":"Female Redwing on Cat Tail"}
            ]
            """
            if let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([FlickrPhoto].self, from: data) {
                photos = decoded
            }

            // Pre-populate detail view with mock info and comments so the
            // photo detail screenshot shows rich metadata instead of spinners.
            let infoJSON = """
            {"photo":{"owner":{"realname":"Wildlife Photographer","location":"San Francisco, CA"},"dates":{"taken":"2026-04-01 09:30:00"},"views":"4812"}}
            """
            mockPhotoInfo = (infoJSON.data(using: .utf8)).flatMap {
                try? JSONDecoder().decode(FlickrInfoResponse.self, from: $0)
            }
            mockPhotoComments = ["Beautiful shot! \u{1F431}", "Love the composition!", "Adorable 😺"]
        }
        #endif
    }

    // MARK: - Search

    func search() {
        guard !apiKey.isEmpty else {
            errorMessage = "Set your API key in the API Key field or via FLICKR_API_KEY env var."
            return
        }
        guard !searchText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        photos = []
        getPhotos(
            apiKey: apiKey,
            photosRequest: FlickrPhotosRequest(text: searchText, page: 1, per_page: 20)
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let fetched):
                    self?.photos = fetched
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - OAuth

    func signIn() {
        guard !apiKey.isEmpty, !apiSecret.isEmpty else {
            authError = "API key and secret are both required to sign in."
            return
        }
        isSigningIn = true
        authError = nil
        performOAuthFlow(
            from: presentationContext,
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: "flickrdemo://oauth"
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSigningIn = false
                switch result {
                case .success(let token):
                    self?.oauthToken = token.oauth_token
                    self?.oauthTokenSecret = token.oauth_token_secret
                    self?.signedInAs = token.fullname.isEmpty ? token.username : token.fullname
                case .failure(let error):
                    self?.authError = error.localizedDescription
                }
            }
        }
    }

    func signOut() {
        oauthToken = ""
        oauthTokenSecret = ""
        signedInAs = nil
    }
}

#if DEBUG
extension DemoViewModel {
    /// Returns PNG Data for a solid gray image at the given pixel side length.
    /// Used by screenshot tests to fill photo view areas without any network call.
    static func screenshotPlaceholderData(side: Int = 300) -> Data? {
        let space = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side,
            space: space,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        ctx.setFillColor(gray: 0.82, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        guard let cgImage = ctx.makeImage() else { return nil }
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutableData, "public.png" as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }
}
#endif
