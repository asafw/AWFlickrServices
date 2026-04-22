---
applyTo: "**"
---

# AWFlickrServices — Copilot Instructions

> Maintained automatically. Update via `.github/CONTEXT.md` + `AGENTS.md`
> and re-sync this file at the end of each session.

## Project overview

A dependency-free Swift Package for integrating the Flickr API in iOS and macOS apps.
Uses a **protocol mixin pattern**: consumers conform to `AWFlickrOAuthProtocol`
or `AWFlickrPhotosProtocol` and gain full API access through protocol extension
default implementations. No subclassing or object injection required.

Originally written in 2020. v2.0 (2026): iOS 16+ / macOS 12+, pure `async throws` API,
zero external dependencies, no UIKit dependency. v3.0 (2026): `AW` prefix added to all
public types (breaking change), detailed inline comments.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **Active branch:** `v2` — all development here; `master` is stable at v3.0.0
- **Authoritative state:** `.github/CONTEXT.md` — always read before making changes.

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum (parsingError, networkError, apiError)
│   ├── FlickrAPIService.swift     ← Internal HTTP layer; decodeFlickrJSON checks stat:fail before decode
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← HMAC-SHA1 signing; rfc3986Encoded + hmacsha1EncryptedString are internal
│   ├── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl (completion + async overloads)
│   └── FlickrService.swift           ← `public final class FlickrService: FlickrPhotosProtocol, FlickrOAuthProtocol {}`
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 73 unit tests (10 suites, CapturingURLProtocol stub)
├── Tests/AWFlickrServicesIntegrationTests/
│   └── AWFlickrServicesIntegrationTests.swift  ← 16 live tests; skip without credentials
├── Examples/FlickrDemoApp/           ← Shared SwiftUI sources (macOS + iOS)
│   ├── DemoViewModel.swift           ← #if DEBUG seams: -mockAuth, AUTO_SEARCH, MOCK_PHOTOS, MOCK_DETAIL
│   └── ContentView.swift             ← .sheet(isPresented: $viewModel.showScreenshotDetail) for MOCK_DETAIL
├── Examples/FlickrDemoApp-iOS/       ← XcodeGen project (iOS 16+)
│   ├── project.yml                   ← Includes FlickrDemoScreenshots UITest target
│   └── Screenshots/FlickrDemoScreenshots.swift  ← 5 screenshot UITests using MOCK_PHOTOS seam
├── screenshots/
│   ├── ios/                          ← 6 PNG screenshots
│   └── macos/                        ← 3 PNG screenshots
├── scripts/
│   ├── ios_screenshots.sh            ← Runs UITests; extracts PNGs via extract_screenshots.py
│   ├── macos_screenshots.sh          ← 3-launch macOS script (empty, mock photos, mock detail)
│   ├── extract_screenshots.py        ← Extracts XCTAttachment PNGs from .xcresult bundles
│   └── capture_macos_window.py       ← Quartz bounds + `screencapture -l <windowID>`; works even when app is behind other windows
├── Package.swift                     ← swift-tools-version:5.9, iOS 16+, macOS 12+; 4 targets (AWFlickrServices, AWFlickrServicesTests, AWFlickrServicesIntegrationTests, FlickrDemoApp)
├── README.md
└── AGENTS.md
```

---

## Types and APIs

### Protocols

| Protocol | Inherits from | Purpose |
|---|---|---|
| `AWFlickrOAuthProtocol` | — | Drives three-legged OAuth 1.0a flow |
| `AWFlickrPhotosProtocol` | — | Photo search, image data download, fave/unfave/comment |

Both protocols use the **mixin pattern**: implement the method signature in the
protocol; provide the full implementation in a `public extension`. Conforming
types get all behaviour for free.

Both `AWFlickrPhotosProtocol` and `AWFlickrOAuthProtocol` declare:
```swift
var urlSession: URLSession { get }   // default: URLSession.shared
```
Conforming types override this to inject a custom session (e.g. a URLProtocol-backed
ephemeral session for tests). Types conforming to both protocols must provide
`urlSession` explicitly to resolve the dual-default ambiguity.

`AWFlickrOAuthProtocol.performOAuthFlow(from:...)` takes an
`ASWebAuthenticationPresentationContextProviding` directly — works on both iOS
and macOS. The `ASWebAuthenticationSession` is retained via
`objc_setAssociatedObject` on the context object so it survives until the
callback fires.

### AWFlickrPhotosProtocol methods

Each method has a **async/await** signature only (pure `async throws`; no completion handlers).

| Method | OAuth required | Async signature |
|---|---|---|
| `getPhotos(apiKey:photosRequest:)` | No | `throws -> [AWFlickrPhoto]` |
| `downloadImageData(from:)` | No | `throws -> Data` |
| `getInfo(apiKey:infoRequest:)` | No | `throws -> AWFlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:)` | No | `throws -> [String]` |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:)` | Yes | `throws` |
| `unfave(...)` | Yes | `throws` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:)` | Yes | `throws` |

`AWFlickrOAuthProtocol.performOAuthFlow` also has an async signature: `throws -> AWAccessTokenResponse`.

### `AWFlickrService`

```swift
public final class AWFlickrService: AWFlickrPhotosProtocol, AWFlickrOAuthProtocol {
    public let urlSession: URLSession
    public init(urlSession: URLSession = .shared)
}
```

Convenience concrete type. Stores `urlSession`; all HTTP behaviour via protocol extension defaults.
Pass a custom `URLSession` at init to intercept requests for testing or custom configuration.

### Public models

| Type | Key fields / notes |
|---|---|
| `AWFlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; URL helpers: `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `AWFlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` — **Int in v2** |
| `AWFlickrFaveRequest` | `photo_id: String` |
| `AWFlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `AWFlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `AWFlickrInfoResponse` | `.photo: AWFlickrPhotoInfo` → `.owner: AWFlickrOwner` (realname, location?), `.dates: AWFlickrDates` (taken), `.views: String` |
| `AWFlickrCommentsRequest` | `photo_id: String` |
| `AWAccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `AWFlickrAPIError` | `.parsingError`, `.networkError`, `.apiError(code: Int, message: String)` |

### Internal types (do not expose publicly)

- `FlickrAPIService` — concrete `URLSession`-based HTTP implementation; `init(session:)` injects the session
- `FlickrEndpoints` — all URL templates and Flickr REST method strings
- `RequestTokenResponse` — intermediate OAuth model
- `FlickrErrorEnvelope` — private struct in `FlickrAPIService.swift` for `stat:fail` detection
- `rfc3986Encoded(_:)` and `hmacsha1EncryptedString(string:key:)` in `FlickrOAuthUtilities.swift` — `internal` (not `public`)

---

## Architecture invariants

- **Zero external dependencies** — `Package.swift` must stay dependency-free.
  `CommonCrypto` is available system-wide on Apple platforms.
- **No UIKit dependency** — iOS 16+ and macOS 12+. `downloadImageData(from:completion:)`
  returns `Data`; callers convert to `UIImage`/`NSImage` themselves.
- **Pure `async throws` API** — all public protocol methods and `FlickrAPIService` methods are `async throws`. No completion handlers remain. `URLSession.data(for:)` (iOS 15+/macOS 12+) is used throughout `FlickrAPIService`.
- **`stat:fail` detection** — `decodeFlickrJSON<T>` checks for `{"stat":"fail",...}` before
  attempting the real type decode and throws `AWFlickrAPIError.apiError(code:message:)`.
  `checkFlickrError(_:)` does the same for void-returning POST endpoints (`fave`, `unfave`, `comment`).
  Both must be applied to all Flickr REST API responses.
  All six affected endpoints have unit test coverage for the stat:fail path.
- **OAuth 1.0a HMAC-SHA1** — signing key is `"apiSecret&oauthTokenSecret"`.
  For the request-token step, `oauthTokenSecret` is empty (`""`), so the key
  is `"apiSecret&"`. This is correct per the OAuth 1.0a spec.
- **RFC 3986 percent-encoding** — all OAuth parameter values are encoded using
  only the unreserved character set (`alphanumerics ∪ "-._~"`). The `internal`
  `rfc3986Encoded(_:)` helper in `FlickrOAuthUtilities.swift` implements this.
- **Alphanumeric OAuth nonce** — `UUID().uuidString` with hyphens stripped.
- **`FlickrPhotosRequest.page` / `per_page` are `Int`** (v2 — changed from `String` in v1).
  The conversion to string is done internally inside `FlickrAPIService`.
- **`Comment.content`** — the Flickr JSON field `_content` is decoded via `CodingKeys`
  into the Swift-idiomatic property name `content`. Do not revert to `_content`.

---

## Coding conventions

- **All source files stay in `Sources/AWFlickrServices/`** — do not split into subdirectories.
- **No imports beyond system frameworks** — `AuthenticationServices`, `Foundation`, `CommonCrypto`, `ObjectiveC`. `UIKit` has been removed.
- **Doc comments** — every `public` type and method should have a `///` doc comment.
- **Tests** — any new public method must have a corresponding unit test using `CapturingURLProtocol`
  and a corresponding integration test in `AWFlickrServicesIntegrationTests`.
- **Integration test credentials** — read from env var or `/tmp/<name>` file via `readCredential(_:)`;
  always skip with `XCTSkipIf` when absent. Never hardcode or commit credentials.
- **`@discardableResult` not needed** — the API is pure `async throws`.

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Unit tests (fast, no network)
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
# All tests including integration (requires /tmp/flickr_api_key)
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" test
```

> `swift build` / `swift test` will fail with "no such module 'AuthenticationServices'" on
> macOS CLI — always use `xcodebuild`.

---

## Session end checklist

1. Run unit tests — all 73 must pass.
2. Update `.github/CONTEXT.md`: latest commit hash, test counts, any changed APIs.
3. Update this file if architecture, conventions, or type descriptions changed.
4. Commit both together:
   ```bash
   git add .github/CONTEXT.md .github/instructions/awflickrservices.instructions.md
   git commit -m "docs(context): update session state"
   git push origin v2
   ```
