# AWFlickrServices — Project Context

> Authoritative AI session state. Always read this before making changes.
> Update at the end of every session that touches code.

---

## Current branch: `v2` (active development)

`master` = v3.1.0 (latest stable — @Observable demo, iOS 17+/macOS 14+)  
`v2` = active development branch — all changes merged to master at 3.1.0

---

## Overview

A Swift Package for integrating the Flickr API in iOS and macOS apps. Has no external dependencies.
Uses a **protocol mixin pattern** — consumers conform to `AWFlickrOAuthProtocol` or
`AWFlickrPhotosProtocol` and gain full API access through protocol extension default implementations.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **v1.0.0:** `master` branch — original 2020 code (tag: `1.0.0`)
- **v2.0.0:** `v2` branch tag — async/await rewrite, urlSession injection, 73 tests
- **v3.0.0:** `master` tag — AW-prefix rename on all public types (breaking), detailed inline comments

---

## What changed in v2

| Area | v1 | v2 |
|---|---|---|
| `swift-tools-version` | 5.2 | 5.9 |
| iOS minimum | 13 | 16 |
| macOS support | none | 12+ |
| `UIKit` dependency | yes (`UIImage`) | removed — `downloadImageData` returns `Data` |
| `FlickrEndpoints` | `struct` with `let` | caseless `enum` with `static let` |
| NS legacy types | `NSDate`, `NSUUID` etc | pure Swift types |
| `URLSession` | hardcoded `.shared` | injected via `FlickrAPIService.init(session:)` |
| HTTP validation | none | `validateHTTPResponse` checks 200–299 |
| Image caching | unreliable | `returnCacheDataElseLoad` |
| `Comment._content` | leading-underscore property | `CodingKeys` mapping → `content` |
| `FlickrPhotosRequest.page`/`per_page` | `String` | `Int` (breaking change) |
| `Sendable` | — | all public structs conform |
| `FlickrAPIError` | `Error` | `Error, Equatable`; `.apiError(code:message:)` added; dead cases removed → **`AWFlickrAPIError`** |
| Flickr `stat:fail` 200 responses | silent DecodingError | detected via `FlickrErrorEnvelope`, thrown as `.apiError` |
| `FlickrOAuthProtocol` context param | `UIViewController` | `ASWebAuthenticationPresentationContextProviding` → **`AWFlickrOAuthProtocol`** |
| `ASWebAuthenticationSession` retention | local var (leaked) | `objc_setAssociatedObject` on context |
| OAuth param sort | locale-sensitive | `sorted()` — lexicographic per spec |
| Percent-encoding | inverted `CharacterSet` (wrong) | RFC 3986 `alphanumerics ∪ "-._~"` |
| OAuth nonce | UUID with hyphens | hyphens stripped — alphanumeric only |
| Encode helper | `urlEncodedString` + `oauthEncodedString` (separate, inconsistent) | unified `rfc3986Encoded(_:)` |
| `rfc3986Encoded` / `hmacsha1EncryptedString` visibility | `private` | `internal` (testable) |
| Key-value OAuth response parser | `components(separatedBy:"=")` silently drops values with `=` | splits on first `=` only via `range(of:)` (A9) |
| `fave`/`unfave`/`comment` on stat:fail 200 | silently returned `.success(())` | calls `checkFlickrError`, throws `.apiError` (A13) |
| `callbackURLScheme` in `ASWebAuthenticationSession` | full URL string (broke matching on some OS versions) | extracts scheme via `URL(string:)?.scheme` (A14) |
| Unit tests | placeholder only | 73 tests across 10 suites |
| Integration tests | none | 16 live tests (2 suites) — skip without credentials |
| API style | completion handlers (`@escaping (Result<T,Error>) -> Void`) | pure `async throws` — no completion handlers |
| CI | none | GitHub Actions `ios.yml` + `macos.yml` |

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum (parsingError, networkError, apiError)
│   ├── FlickrAPIService.swift     ← Internal HTTP layer; decodeFlickrJSON checks stat:fail
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← HMAC-SHA1 signing; rfc3986Encoded + hmacsha1EncryptedString internal
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Examples/FlickrDemoApp/           ← Shared SwiftUI source files (macOS + iOS)
│   ├── FlickrDemoApp.swift           ← @main App; NSApp.activate on macOS via #if canImport(AppKit)
│   ├── DemoViewModel.swift           ← @Observable; conforms to `AWFlickrPhotosProtocol` + `AWFlickrOAuthProtocol`
│   ├── ContentView.swift             ← NavigationStack + API key field
│   ├── AuthView.swift                ← OAuth sign-in/sign-out panel with API secret SecureField
│   ├── PhotoGridView.swift           ← LazyVGrid thumbnails; PlatformImage cross-platform alias
│   ├── PhotoDetailView.swift         ← HStack/VStack adaptive via horizontalSizeClass; @State actionError shows fave/comment failures
│   ├── PlatformImage.swift           ← typealias PlatformImage = NSImage/UIImage + Image(platformImage:)
│   └── PresentationContext.swift     ← ASWebAuthenticationPresentationContextProviding; iOS uses UIWindowScene.keyWindow (iOS 15+)
├── Examples/FlickrDemoApp-iOS/       ← XcodeGen project (iOS 17+); reuses FlickrDemoApp/ sources
│   ├── project.yml                   ← XcodeGen spec; run `xcodegen generate` to create .xcodeproj
│   ├── Screenshots/FlickrDemoScreenshots.swift  ← UITest screenshot pipeline (5 tests; MOCK_PHOTOS seam)
│   └── .gitignore                    ← ignores the generated .xcodeproj
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 73 unit tests (10 suites, CapturingURLProtocol stub)
├── Tests/AWFlickrServicesIntegrationTests/
│   └── AWFlickrServicesIntegrationTests.swift  ← 16 live tests (FlickrSearchIntegrationTests + FlickrOAuthIntegrationTests)
├── screenshots/
│   ├── ios/                          ← 6 PNG screenshots: ios_empty_state, ios_signed_in, ios_search_results, ios_photo_detail, ios_search_results_authenticated, ios_detail_authenticated
│   └── macos/                        ← 3 PNG screenshots (empty_state, search_results, photo_detail)
├── scripts/
│   ├── ios_screenshots.sh            ← Runs FlickrDemoScreenshots UITests; extracts PNGs to screenshots/ios/
│   ├── macos_screenshots.sh          ← Launches macOS app 3 times (empty, mock photos, mock detail); captures windows
│   ├── extract_screenshots.py        ← Extracts XCTAttachment PNGs from .xcresult bundles
│   └── capture_macos_window.py       ← Quartz bounds + screencapture -R; no accessibility permissions needed
├── Package.swift                     ← swift-tools-version:5.9, iOS 17+, macOS 14+; 4 targets
├── README.md
├── AGENTS.md
└── .github/
    ├── CONTEXT.md
    ├── instructions/awflickrservices.instructions.md
    ├── workflows/ios.yml
    └── workflows/macos.yml
```

---

## Public API surface

### AWFlickrPhotosProtocol methods (all `async throws`)

| Method | OAuth required | Return type |
|---|---|---|
| `getPhotos(apiKey:photosRequest:)` | No | `[AWFlickrPhoto]` |
| `downloadImageData(from:)` | No | `Data` (`returnCacheDataElseLoad`) |
| `getInfo(apiKey:infoRequest:)` | No | `AWFlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:)` | No | `[String]` |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:)` | Yes | `Void` |
| `unfave(...)` | Yes | `Void` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:)` | Yes | `Void` |

### Public models

| Type | Key fields / notes |
|---|---|
| `AWFlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `AWFlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` |
| `AWFlickrFaveRequest` | `photo_id: String` |
| `AWFlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `AWFlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `AWFlickrInfoResponse` | `.photo: AWFlickrPhotoInfo` → `.owner: AWFlickrOwner` (realname, location?), `.dates: AWFlickrDates` (taken), `.views: String` |
| `AWFlickrCommentsRequest` | `photo_id: String` |
| `AWAccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `AWFlickrAPIError` | `.parsingError`, `.networkError`, `.apiError(code: Int, message: String)` |

---

## Architecture invariants

- **`urlSession` protocol requirement** — both `AWFlickrPhotosProtocol` and `AWFlickrOAuthProtocol` expose `var urlSession: URLSession { get }` with a default of `URLSession.shared`. Protocol extension default implementations create `FlickrAPIService(session: urlSession)` — conforming types override only `urlSession` to inject a test or custom session without overriding every method.
- **Zero external dependencies** — `Package.swift` must stay dependency-free.
- **No UIKit dependency** — iOS 16+ and macOS 12+. `downloadImageData` returns `Data`.
- **Pure `async throws` API** — all public protocol methods and `FlickrAPIService` methods use `async throws`. No completion handlers remain in the public API.
- **`URLSession.data(for:)`** — iOS 15+/macOS 12+ async API used in `FlickrAPIService`. Works with `CapturingURLProtocol` in tests.
- **`stat:fail` detection** — `decodeFlickrJSON<T>` checks stat:fail for GET/decode endpoints (`getPhotos`, `getInfo`, `getComments`); `checkFlickrError(_:)` checks stat:fail for void POST endpoints (`fave`, `unfave`, `comment`). Both throw `.apiError(code:message:)`. All six endpoints have unit test coverage.
- **OAuth 1.0a HMAC-SHA1** — signing key is `"apiSecret&oauthTokenSecret"`. Request-token step uses `"apiSecret&"` (empty token secret).
- **RFC 3986 percent-encoding** — unified `rfc3986Encoded(_:)` helper; `alphanumerics ∪ "-._~"` only.
- **Alphanumeric nonce** — `UUID().uuidString.replacingOccurrences(of: "-", with: "")`.
- **`rfc3986Encoded` and `hmacsha1EncryptedString` are `internal`** — exposed for unit testing; do not make `public`.
- **`Comment.content`** — Flickr JSON `_content` mapped via `CodingKeys`. Do not revert to `_content`.

---

## Tests

### Unit tests — 73 passing

| Suite | Count | What it covers |
|---|---|---|
| `FlickrEndpointsTests` | 2 | host URL, URL template suffixes |
| `FlickrPhotoTests` | 2 | thumbnail / large URL format |
| `FlickrPhotosRequestTests` | 1 | page/per_page stored as Int |
| `FlickrModelsDecodingTests` | 3 | FlickrInfoResponse, Owner nil location, Comment CodingKey |
| `FlickrAPIServiceURLBuildingTests` | 24 | URL params for all 8 methods, cache policy, HTTP 4xx, stat:fail → apiError for getPhotos/getInfo/getComments/fave/unfave/comment, fave/unfave/comment success, downloadImageData HTTP error, oauth_signature present — all `async throws` |
| `FlickrAPIServiceOAuthParsingTests` | 7 | request/access token key-value parsing, HTTP error paths, A9 `=` in token secret, missing field → parsingError — all `async throws` |
| `RFC3986EncodingTests` | 7 | space, &, =, +, #, /, unreserved passthrough |
| `OAuthUtilitiesTests` | 9 | RFC 2202 HMAC-SHA1 vector, all 7 required OAuth params, HMAC-SHA1 method, version 1.0, nonce alphanumeric, callback in request token URL, verifier + token in access token URL, signing key uses empty token secret |
| `FlickrPhotosProtocolAsyncTests` | 15 | `StubBackedService` (implements async protocol requirements, delegates to injected `FlickrAPIService`); all 7 protocol methods success and error paths |
| `FlickrServiceTests` | 3 | `AWFlickrService` instantiation, conformance to both protocols |

Run unit tests:
```bash
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
```

### Integration tests — 16 total (skip gracefully without credentials)

**`FlickrSearchIntegrationTests` (14 tests)** — require `FLICKR_API_KEY` / `/tmp/flickr_api_key`:
per_page count, pagination distinct IDs, spaces in search term, invalid key → apiError,
page-beyond-total no error, farm thumbnail resolves, large URL resolves, JPEG magic bytes,
getInfo decodes, views numeric, getComments decodes, concurrent searches, farm CDN canary.

**`FlickrOAuthIntegrationTests` (2 tests)** — require `FLICKR_API_SECRET` / `/tmp/flickr_api_secret`:
- `testGetRequestTokenSigningIsAcceptedByFlickr` — proves entire signing chain (HMAC-SHA1, key format, nonce, encoding) by getting Flickr to accept the signed request
- `testFaveAndUnfaveRoundTrip` — also requires `/tmp/flickr_oauth_token` + `/tmp/flickr_oauth_token_secret`

Run integration tests:
```bash
echo "your_secret" > /tmp/flickr_api_secret   # for OAuth tests
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesIntegrationTests test
```

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Unit tests (fast, no network)
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
# Integration tests (live network — requires /tmp/flickr_api_key)
xcodebuild -scheme AWFlickrServices-Package -destination "platform=macOS" -only-testing:AWFlickrServicesIntegrationTests test
```

> `swift test` fails with "no such module 'AuthenticationServices'" — always use `xcodebuild`.

## Demo app

### macOS (swift run)

```bash
cd ~/Desktop/asafw/AWFlickrServices

# Option 1 — env var (no files left on disk)
FLICKR_API_KEY=your_api_key swift run FlickrDemoApp

# Option 2 — credential file
echo "your_api_key" > /tmp/flickr_api_key
swift run FlickrDemoApp
```

- Reads key from `FLICKR_API_KEY` env var first; falls back to `/tmp/flickr_api_key`.
- `FlickrDemoApp.swift` calls `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(ignoringOtherApps: true)` in `.onAppear` to work around the standard macOS behaviour where `swift run`-launched processes don’t become the foreground app.
- macOS 14+ uses `NavigationStack`. `ContentView` no longer needs an `#available` guard.

### iOS Simulator

```bash
# Build (from Examples/FlickrDemoApp-iOS/)
cd ~/Desktop/asafw/AWFlickrServices/Examples/FlickrDemoApp-iOS
xcodegen generate --quiet
xcodebuild -scheme FlickrDemoApp-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build

# Boot + install
UDID=A1042622-0426-4FF9-94B3-0427070B3921   # iPhone 16 simulator
xcrun simctl boot "$UDID" 2>/dev/null; open -a Simulator
xcrun simctl install "$UDID" \
  ~/Library/Developer/Xcode/DerivedData/FlickrDemoApp-iOS-*/Build/Products/Debug-iphonesimulator/Flickr\ Demo.app

# Launch with API key — use SIMCTL_CHILD_ prefix (--setenv not supported in this Xcode version)
SIMCTL_CHILD_FLICKR_API_KEY="$(cat /tmp/flickr_api_key | tr -d '[:space:]')" \
  xcrun simctl launch "$UDID" com.example.flickrdemo
```

- **Bundle ID:** `com.example.flickrdemo`
- **App bundle name:** `Flickr Demo.app` (note the space)
- **`SIMCTL_CHILD_*`** — simctl strips the prefix and injects the remainder as an env var into the spawned process. This is the only way to pass env vars via CLI in Xcode 16+; `--setenv` is not supported.
- Layout adapts via `@Environment(\.horizontalSizeClass)`: VStack (compact/iPhone), HStack with sidebar (regular/iPad/macOS).

---

## Commit history (latest 10)

```
4b1c669  docs: bump README to v3.1.0 (iOS 17+/macOS 14+, @Observable migration note)
71fa8f2  refactor(demo): migrate DemoViewModel to @Observable; bump platform to iOS 17+/macOS 14+
3788b0e  docs(context): update session state after CI fixes and README update
cbe46aa  ci: fix YAML syntax in iOS test step (single-line Python)
f51504c  docs: pin CI badges to master branch
7f76e7a  ci: dynamically select first available iPhone simulator for iOS tests
fe47777  ci: use Any iOS Simulator Device destination to fix runner compatibility
90fa866  docs: update README to v3.0.0 (AW prefix, async/await examples, migration guide)
b44039f  docs(context): sync instructions and context with 3.0.0 state
37f4ad8  ci: fix scheme name to AWFlickrServices-Package
```

---

## Architecture decisions

### `urlSession` protocol requirement (added v2.0)

Both `AWFlickrPhotosProtocol` and `AWFlickrOAuthProtocol` expose:

```swift
var urlSession: URLSession { get }
```

with a default implementation in the protocol extension that returns `URLSession.shared`.

The internal `FlickrAPIService` type is the actual HTTP layer; it accepts a `URLSession` at
init (`FlickrAPIService(session:)`). Without `urlSession`, the protocol extension computed
property `private var service: FlickrAPIService { FlickrAPIService() }` created a new service
on every method call with no way for conforming types to inject a different session.

`FlickrAPIService` is intentionally kept `internal` to avoid committing it to the public API.
Exposing `URLSession` (a system type) instead gives consumers full control — custom
`URLProtocol` subclasses for testing, custom caching or timeout configuration for
production — without leaking the internal HTTP layer. Conforming types that don't need
customisation pay zero overhead; the default `URLSession.shared` is returned automatically.

Practical benefit: `StubBackedService` in unit tests collapsed from ~60 lines
(overriding every protocol method to delegate to an injected service) to 2 lines:

```swift
private struct StubBackedService: FlickrPhotosProtocol {
    let urlSession: URLSession
}
```

---

## Remaining work

- Tag `2.0.0` and merge `v2` → `master`
- ✅ `urlSession` protocol requirement — session injection via override, `StubBackedService` simplified
- ✅ Pure `async throws` API — all closure-based API removed (breaking change vs v1)
- ✅ `FlickrService` concrete class added
