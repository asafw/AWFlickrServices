// DemoViewModel.swift — Observable state connecting the UI to AWFlickrServices.

import CoreGraphics
import Foundation
import Combine
import ImageIO
import AWFlickrServices

/// Drives the demo UI. Conforms to FlickrPhotosProtocol and FlickrOAuthProtocol
/// so it can exercise the full public API surface of AWFlickrServices.
final class DemoViewModel: ObservableObject, AWFlickrPhotosProtocol, AWFlickrOAuthProtocol {

    // Both protocols declare `urlSession`; provide it explicitly to resolve
    // the dual-conformance ambiguity. URLSession.shared is sufficient for the demo.
    var urlSession: URLSession { .shared }
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
    @Published var photos: [AWFlickrPhoto] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    /// Set by MOCK_DETAIL seam — ContentView presents a detail sheet for the first photo.
    @Published var showScreenshotDetail: Bool = false

    private var cancellables = Set<AnyCancellable>()

    #if DEBUG
    /// Pre-populated by MOCK_PHOTOS seam so PhotoDetailView skips network calls.
    var mockPhotoInfo: AWFlickrInfoResponse? = nil
    var mockPhotoComments: [String] = []
    #endif

    // MARK: - Init

    init() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments

        // UITest / screenshot seam: pass -mockAuth in launchArguments to pre-seed
        // a fake OAuth token so photo detail shows fave/comment controls.
        if args.contains("-mockAuth") || env["MOCK_AUTH"] != nil {
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

        // MOCK_DETAIL seam: opens the detail sheet for the first photo once photos are loaded.
        // Works with both MOCK_PHOTOS (instant) and AUTO_SEARCH (async).
        if env["MOCK_DETAIL"] != nil {
            if env["MOCK_PHOTOS"] != nil {
                // Photos will be set synchronously below — open sheet immediately.
                showScreenshotDetail = true
            } else {
                // Photos arrive asynchronously via search; observe and open once they appear.
                $photos
                    .filter { !$0.isEmpty }
                    .first()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in self?.showScreenshotDetail = true }
                    .store(in: &cancellables)
            }
        }

        if env["MOCK_PHOTOS"] != nil {
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
               let decoded = try? JSONDecoder().decode([AWFlickrPhoto].self, from: data) {
                photos = decoded
            }

            // Pre-populate detail view with mock info and comments so the
            // photo detail screenshot shows rich metadata instead of spinners.
            let infoJSON = """
            {"photo":{"owner":{"realname":"Wildlife Photographer","location":"San Francisco, CA"},"dates":{"taken":"2026-04-01 09:30:00"},"views":"4812"}}
            """
            mockPhotoInfo = (infoJSON.data(using: .utf8)).flatMap {
                try? JSONDecoder().decode(AWFlickrInfoResponse.self, from: $0)
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
        Task { @MainActor in
            do {
                let fetched = try await getPhotos(
                    apiKey: apiKey,
                    photosRequest: AWFlickrPhotosRequest(text: searchText, page: 1, per_page: 20)
                )
                isLoading = false
                photos = fetched
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
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
        Task { @MainActor in
            do {
                let token = try await performOAuthFlow(
                    from: presentationContext,
                    apiKey: apiKey,
                    apiSecret: apiSecret,
                    callbackUrlString: "flickrdemo://oauth"
                )
                isSigningIn = false
                oauthToken = token.oauth_token
                oauthTokenSecret = token.oauth_token_secret
                signedInAs = token.fullname.isEmpty ? token.username : token.fullname
            } catch {
                isSigningIn = false
                authError = error.localizedDescription
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
    /// Returns PNG Data for a diagonal gradient image seeded by `seed`.
    /// Different URL strings produce visually distinct gradient colours so the
    /// screenshot grid looks like real photos rather than identical grey boxes.
    static func screenshotPlaceholderData(seed: String = "", side: Int = 300) -> Data? {
        // 12 warm/cool palettes: (topLeft R,G,B), (bottomRight R,G,B)
        let palettes: [((CGFloat, CGFloat, CGFloat), (CGFloat, CGFloat, CGFloat))] = [
            ((0.95, 0.60, 0.30), (0.80, 0.40, 0.15)),  // amber
            ((0.30, 0.55, 0.90), (0.15, 0.35, 0.75)),  // blue
            ((0.35, 0.72, 0.45), (0.15, 0.52, 0.25)),  // green
            ((0.70, 0.35, 0.75), (0.50, 0.15, 0.55)),  // purple
            ((0.92, 0.75, 0.20), (0.72, 0.55, 0.10)),  // golden
            ((0.20, 0.72, 0.82), (0.10, 0.52, 0.62)),  // teal
            ((0.88, 0.30, 0.30), (0.68, 0.10, 0.10)),  // red
            ((0.50, 0.42, 0.85), (0.30, 0.22, 0.65)),  // indigo
            ((0.28, 0.62, 0.28), (0.10, 0.42, 0.10)),  // dark green
            ((0.92, 0.52, 0.62), (0.72, 0.32, 0.42)),  // rose
            ((0.62, 0.42, 0.28), (0.42, 0.22, 0.10)),  // brown
            ((0.42, 0.72, 0.72), (0.22, 0.52, 0.52)),  // cyan
        ]
        // Stable DJB2 hash — does not use Swift.hashValue (non-deterministic).
        var h: Int = 5381
        for c in seed.utf8 { h = (h &<< 5) &+ h &+ Int(c) }
        let palette = palettes[abs(h) % palettes.count]

        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        let c1 = palette.0, c2 = palette.1
        guard
            let startColor = CGColor(colorSpace: space, components: [c1.0, c1.1, c1.2, 1.0]),
            let endColor   = CGColor(colorSpace: space, components: [c2.0, c2.1, c2.2, 1.0]),
            let gradient   = CGGradient(
                colorsSpace: space,
                colors: [startColor, endColor] as CFArray,
                locations: [0.0, 1.0]
            )
        else { return nil }

        // Draw diagonal gradient: lighter tone at visual top-left, darker at bottom-right.
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(side)),
            end:   CGPoint(x: CGFloat(side), y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )

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
