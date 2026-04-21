# AWFlickrServices — Project Context

> Authoritative AI session state. Always read this before making changes.
> Update at the end of every session that touches code.

---

## Current branch: `v2` (active development)

`master` = v1.0.0 (original, frozen — kept for existing consumers)  
`v2` = modernised v2.0.0 work in progress — all Phase 1–3 improvements applied

---

## Overview

A dependency-free Swift Package (SPM) for integrating the Flickr API in iOS and macOS apps.
Uses a **protocol mixin pattern** — consumers conform to `FlickrOAuthProtocol` or
`FlickrPhotosProtocol` and gain full API access through protocol extension default implementations.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **v1.0.0:** `master` branch — original 2020 code, frozen
- **v2.0.0 (WIP):** `v2` branch — modernised, tested, iOS 16+ and macOS 12+

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
| `URLSession` | hardcoded `.shared` | injected via `FlickrAPIRepository.init(session:)` |
| HTTP validation | none | `validateHTTPResponse` checks 200–299 |
| Image caching | unreliable | `returnCacheDataElseLoad` |
| `Comment._content` | leading-underscore property | `CodingKeys` mapping → `content` |
| `FlickrPhotosRequest.page`/`per_page` | `String` | `Int` (breaking change) |
| `Sendable` | — | all public structs conform |
| `FlickrAPIError` | `Error` | `Error, Equatable`; `.apiError(code:message:)` added; dead cases removed |
| Flickr `stat:fail` 200 responses | silent DecodingError | detected via `FlickrErrorEnvelope`, thrown as `.apiError` |
| `FlickrOAuthProtocol` context param | `UIViewController` | `ASWebAuthenticationPresentationContextProviding` |
| `ASWebAuthenticationSession` retention | local var (leaked) | `objc_setAssociatedObject` on context |
| OAuth param sort | locale-sensitive | `sorted()` — lexicographic per spec |
| Percent-encoding | inverted `CharacterSet` (wrong) | RFC 3986 `alphanumerics ∪ "-._~"` |
| OAuth nonce | UUID with hyphens | hyphens stripped — alphanumeric only |
| Encode helper | `urlEncodedString` + `oauthEncodedString` (separate, inconsistent) | unified `rfc3986Encoded(_:)` |
| `rfc3986Encoded` / `hmacsha1EncryptedString` visibility | `private` | `internal` (testable) |
| Key-value OAuth response parser | `components(separatedBy:"=")` silently drops values with `=` | splits on first `=` only via `range(of:)` (A9) |
| `fave`/`unfave`/`comment` on stat:fail 200 | silently returned `.success(())` | calls `checkFlickrError`, throws `.apiError` (A13) |
| `callbackURLScheme` in `ASWebAuthenticationSession` | full URL string (broke matching on some OS versions) | extracts scheme via `URL(string:)?.scheme` (A14) |
| Unit tests | placeholder only | 46 tests across 8 suites |
| Integration tests | none | 16 live tests (2 suites) — skip without credentials |
| CI | none | GitHub Actions `ios.yml` |

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum (parsingError, networkError, apiError)
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer; decodeFlickrJSON checks stat:fail
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← HMAC-SHA1 signing; rfc3986Encoded + hmacsha1EncryptedString internal
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Examples/FlickrDemoApp/           ← Shared SwiftUI source files (macOS + iOS)
│   ├── FlickrDemoApp.swift           ← @main App; NSApp.activate on macOS via #if canImport(AppKit)
│   ├── DemoViewModel.swift           ← ObservableObject; conforms to FlickrPhotosProtocol + FlickrOAuthProtocol
│   ├── ContentView.swift             ← NavigationStack (13+) / NavigationView (12) + API key field
│   ├── AuthView.swift                ← OAuth sign-in/sign-out panel with API secret SecureField
│   ├── PhotoGridView.swift           ← LazyVGrid thumbnails; PlatformImage cross-platform alias
│   ├── PhotoDetailView.swift         ← HStack/VStack adaptive via horizontalSizeClass; @State actionError shows fave/comment failures
│   ├── PlatformImage.swift           ← typealias PlatformImage = NSImage/UIImage + Image(platformImage:)
│   └── PresentationContext.swift     ← ASWebAuthenticationPresentationContextProviding; iOS uses UIWindowScene.keyWindow (iOS 15+)
├── Examples/FlickrDemoApp-iOS/       ← XcodeGen project (iOS 16+); reuses FlickrDemoApp/ sources
│   ├── project.yml                   ← XcodeGen spec; run `xcodegen generate` to create .xcodeproj
│   └── .gitignore                    ← ignores the generated .xcodeproj
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 55 unit tests (8 suites, CapturingURLProtocol stub)
├── Tests/AWFlickrServicesIntegrationTests/
│   └── AWFlickrServicesIntegrationTests.swift  ← 16 live tests (FlickrSearchIntegrationTests + FlickrOAuthIntegrationTests)
├── Package.swift                     ← swift-tools-version:5.9, iOS 16+, macOS 12+; 4 targets
├── README.md
├── AGENTS.md
└── .github/
    ├── CONTEXT.md
    ├── instructions/awflickrservices.instructions.md
    └── workflows/ios.yml
```

---

## Public API surface

### FlickrPhotosProtocol methods

| Method | OAuth required | Return type |
|---|---|---|
| `getPhotos(apiKey:photosRequest:completion:)` | No | `[FlickrPhoto]` |
| `downloadImageData(from:completion:)` | No | `Data` (`returnCacheDataElseLoad`) |
| `getInfo(apiKey:infoRequest:completion:)` | No | `FlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:completion:)` | No | `[String]` |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:completion:)` | Yes | `Void` |
| `unfave(...)` | Yes | `Void` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:completion:)` | Yes | `Void` |

### Public models

| Type | Key fields / notes |
|---|---|
| `FlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner` (realname, location?), `.dates: Dates` (taken), `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError`, `.apiError(code: Int, message: String)` |

---

## Architecture invariants

- **Zero external dependencies** — `Package.swift` must stay dependency-free.
- **No UIKit dependency** — iOS 16+ and macOS 12+. `downloadImageData` returns `Data`.
- **Completion-handler API** — `@escaping (Result<T, Error>) -> Void`. Callbacks on URLSession background queue.
- **`stat:fail` detection** — `decodeFlickrJSON<T>` checks stat:fail for GET/decode endpoints (`getPhotos`, `getInfo`, `getComments`); `checkFlickrError(_:)` checks stat:fail for void POST endpoints (`fave`, `unfave`, `comment`). Both throw `.apiError(code:message:)`. All six endpoints have unit test coverage.
- **OAuth 1.0a HMAC-SHA1** — signing key is `"apiSecret&oauthTokenSecret"`. Request-token step uses `"apiSecret&"` (empty token secret).
- **RFC 3986 percent-encoding** — unified `rfc3986Encoded(_:)` helper; `alphanumerics ∪ "-._~"` only.
- **Alphanumeric nonce** — `UUID().uuidString.replacingOccurrences(of: "-", with: "")`.
- **`rfc3986Encoded` and `hmacsha1EncryptedString` are `internal`** — exposed for unit testing; do not make `public`.
- **`Comment.content`** — Flickr JSON `_content` mapped via `CodingKeys`. Do not revert to `_content`.

---

## Tests

### Unit tests — 55 passing

| Suite | Count | What it covers |
|---|---|---|
| `FlickrEndpointsTests` | 2 | host URL, URL template suffixes |
| `FlickrPhotoTests` | 2 | thumbnail / large URL format |
| `FlickrPhotosRequestTests` | 1 | page/per_page stored as Int |
| `FlickrModelsDecodingTests` | 4 | FlickrInfoResponse, Owner nil location, Comment CodingKey, AccessTokenResponse |
| `FlickrAPIRepositoryURLBuildingTests` | 25 | URL params for all 8 methods, cache policy, HTTP 4xx, stat:fail → apiError for getPhotos/getInfo/getComments/fave/unfave/comment, fave/unfave/comment success (.success(())), downloadImageData HTTP error, oauth_signature present |
| `FlickrAPIRepositoryOAuthParsingTests` | 7 | request/access token key-value parsing, HTTP error paths, A9 `=` in token secret (both getAccessToken and getRequestToken), A13 stat:fail on fave |
| `RFC3986EncodingTests` | 7 | space, &, =, +, #, /, unreserved passthrough |
| `OAuthUtilitiesTests` | 9 | RFC 2202 HMAC-SHA1 vector, all 7 required OAuth params, HMAC-SHA1 method, version 1.0, nonce alphanumeric, callback in request token URL, verifier + token in access token URL, signing key uses empty token secret |

Run unit tests:
```bash
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
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
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" -only-testing:AWFlickrServicesIntegrationTests test
```

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Unit tests (fast, no network)
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
# Integration tests (live network — requires /tmp/flickr_api_key)
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" -only-testing:AWFlickrServicesIntegrationTests test
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
- macOS 12 uses `NavigationView`; macOS 13+ uses `NavigationStack` (both via `#available` in ContentView).

### iOS Simulator (Xcode project)

```bash
# Generate the Xcode project (XcodeGen must be installed: brew install xcodegen)
cd ~/Desktop/asafw/AWFlickrServices/Examples/FlickrDemoApp-iOS
xcodegen generate  # creates FlickrDemoApp-iOS.xcodeproj (gitignored)
open FlickrDemoApp-iOS.xcodeproj
```

In Xcode: set `FLICKR_API_KEY` env var in **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, then ⌘R.
If the key is not set via env var, an "API Key" text field appears in the app UI on first launch.

Layout adapts via `@Environment(\.horizontalSizeClass)`: VStack (compact/iPhone), HStack with sidebar (regular/iPad/macOS).

---

## Commit history (latest 8)

```
fe78db9  test+fix: audit — B1-B4 success paths/HTTP error tests; D1 deprecated keyWindow API; D2 demo error feedback
fe78db9  test+fix: audit — B1-B4 success paths/HTTP error tests; D1 deprecated keyWindow API; D2 demo error feedback
97643d9  feat(examples): iOS demo app — cross-platform source files, NavigationStack/View #available, XcodeGen project
40fd275  feat(examples): add OAuth flow, fave/unfave/comment to demo — full API coverage
c81b0a3  docs(context): sync after cross-platform + iOS demo build
1b7098a  docs: add FlickrDemoApp launch instructions to README and CONTEXT
90a8cd1  fix(demo): activate app on appear so TextField responds to keyboard input
cf5ab69  feat(examples): add FlickrDemoApp SPM target — SwiftUI macOS demo of search, thumbnails, photo detail, getInfo, getComments
b4d6ff3  test: audit — stat:fail coverage for getInfo/getComments/unfave/comment, A9 regression for getRequestToken
e211f49  docs(context): remove stale duplicate section, add missing docs-sync commit to history
552deb7  docs(context): sync after A9/A13/A14 fixes — 46 unit tests
c57a07d  fix: A9 key-value parser splits on first = only, A13 stat:fail on POST endpoints, A14 callbackURLScheme extracts scheme
ee81f4c  docs(context): sync CONTEXT.md and instructions after session — 44 unit tests, 16 integration tests, apiError, OAuthUtilitiesTests
f91b83d  test: OAuth 1.0a coverage — RFC 2202 HMAC-SHA1 vector, signing key format, all params, live getRequestToken + fave/unfave tests
3f2ef8c  fix: detect Flickr stat:fail 200-responses as FlickrAPIError.apiError, add unit + integration test
6218989  test(integration): add 9 new live tests — per_page, pagination, spaces, invalid key, page clamp, large URL, JPEG magic bytes, views numeric, concurrency
```

---

## Remaining work (Phase 3–4, future)

- Phase 3: `FlickrAPIRepository` injection via protocol (currently instantiated per-method-call in the protocol extensions)
- Phase 4: `async`/`await` overloads via `withCheckedThrowingContinuation`
- Phase 4: `FlickrService` class wrapper for SwiftUI consumers
- Tag `2.0.0` and merge `v2` → `master` when Phase 3–4 are complete


Run: `xcodebuild -scheme AWFlickrServices -destination "platform=iOS Simulator,name=iPhone 16" test`

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Build
xcodebuild -scheme AWFlickrServices -destination "generic/platform=iOS Simulator" build
# Test
xcodebuild -scheme AWFlickrServices -destination "platform=iOS Simulator,name=iPhone 16" test
```

---

## Commit history

```
(v2 branch)
a55838f   test: coverage improvements — decoded results, OAuth parsing, oauth_signature, RFC 3986 edge cases (34 tests)
f5d139a   fix: S6-S8 OAuth encoding — RFC 3986 percent-encoding, alphanumeric nonce, merge encode helpers
81d421b   feat: S1-S5 audit fixes + cross-platform refactor (iOS + macOS)
1e73143   fix(v2): public FlickrPhoto fields, HMAC utf8 byte count, add URL-building tests
2bb25d5   fix(v2): audit fixes — Equatable error, public photo_id, nil-URL completions, OAuthProtocol consistency, test tearDown
93d5920   feat(v2): Phase 1+2 modernisation — NS types, FlickrEndpoints enum, URLSession injection, HTTP validation, page/per_page Int, Sendable, 13 unit tests, CI workflow
2977c1d   docs(context): add CONTEXT.md, AGENTS.md, and Copilot instructions
442d7cb   Updated total JSON field from String to Int
febaa49   Fixed typo in Readme
ccd3bc5   Version 1.0.0
9320964   Initial commit
```

---

## Remaining work (Phase 3–4, future)

- Change `FlickrPhotosRequest.page`/`per_page` public init already done (Int)
- Phase 3: `FlickrAPIRepository` injection via protocol (currently instantiated per-method-call)
- Phase 4: `async`/`await` overloads via `withCheckedThrowingContinuation`
- Phase 4: `FlickrService` class wrapper for SwiftUI consumers
- Tag `2.0.0` on `v2` branch when Phase 3–4 are complete, then merge to master

---

## Tests

- **Current state:** Placeholder only — `testExample` is commented out.
- **Real tests needed:** URL-building, OAuth parameter generation, model parsing.
- Run: `swift test` (from repo root)

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
swift build
swift test
```

---

## Commit history

```
442d7cb  Updated total JSON field from String to Int
febaa49  Fixed typo in Readme
ccd3bc5  Version 1.0.0
9320964  Initial commit
```

---

## Known issues / potential improvements

- No real unit tests — only the SPM-generated placeholder.
- `FlickrAPIRepository` uses `URLSession.shared` with no injectable session — cannot be
  unit tested without refactoring to accept a `URLSession` parameter.
- `FlickrPhotosRequest.page` / `per_page` are `String` but conceptually integers — could
  be changed to `Int` with string conversion moved inside the repository. (`total` field
  in `FlickrPhotos` was already changed from `String` to `Int` in commit `442d7cb`.)
- Completion handlers fire on the URLSession background queue — callers must dispatch to
  main queue themselves for UI updates.
- No Swift 5.5+ async/await overloads.
- `swift-tools-version` is 5.2 — could be bumped to 5.9 for modern package features.
