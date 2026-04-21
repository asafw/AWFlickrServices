# AWFlickrServices — Project Context

> Authoritative AI session state. Always read this before making changes.
> Update at the end of every session that touches code.

---

## Current branch: `v2` (active development)

`master` = v1.0.0 (original, frozen — kept for existing consumers)
`v2` = modernised v2.0.0 work in progress — all Phase 1 & 2 improvements applied

---

## Overview

A dependency-free Swift Package (SPM) for integrating the Flickr API in iOS apps.
Covers OAuth 1.0a (three-legged flow) and core Flickr REST methods via a
protocol-mixin design pattern — consumers conform to `FlickrOAuthProtocol` or
`FlickrPhotosProtocol` in their view controllers and call the default-implemented
methods directly.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **v1.0.0:** `master` branch — original 2020 code, frozen
- **v2.0.0 (WIP):** `v2` branch — modernised, tested, iOS 16+

---

| v2 changes vs v1 — audit fixes applied (v2.1)

| Area | v1 | v2 |
|---|---|---|
| `swift-tools-version` | 5.2 | 5.9 |
| iOS minimum | 13 | 16 |
| `FlickrEndpoints` | `struct` with `let` | caseless `enum` with `static let` |
| NS legacy types | `NSDate`, `NSUUID`, `NSCharacterSet`, `NSURLComponents` | pure Swift types |
| OAuth typo | `encriptedURLWithBaseURL` | `encryptedURLWithBaseURL` |
| Dead code | `generatePermsURL` + `permsEndpoint` + `getFavoritesEndPoint` | removed |
| `URLSession` | hardcoded `.shared` | injected via `FlickrAPIRepository.init(session:)` |
| HTTP validation | none | `validateHTTPResponse` checks 200–299 |
| `getImage` caching | unreliable (bare URL dataTask) | `URLRequest(cachePolicy: .returnCacheDataElseLoad)` |
| `Comment._content` | leading-underscore property | `CodingKeys` mapping, property is `content` |
| `FlickrPhotosRequest.page`/`per_page` | `String` | `Int` (breaking change) |
| `Sendable` | — | all public structs conform |
| `FlickrAPIError` | `Error` | `Error, Equatable` |
| `FlickrCommentsRequest.photo_id` | internal | `public` |
| nil-URL silent returns in OAuth | silent | calls `completion(.failure(.parsingError))` |
| `FlickrOAuthProtocol` repository | inline `FlickrAPIRepository()` per call | `private var repository` computed property |
| Test tearDown | missing | resets `CapturingURLProtocol` shared state |
| Linux test artifacts | present | removed |
| Unit tests | placeholder only | 13 tests across 5 suites |
| CI | none | GitHub Actions `ios.yml` |

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer (URLSession, injected)
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public, Sendable)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← Internal HMAC-SHA1 signing utilities (pure Swift)
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 13 unit tests (5 suites)
├── Package.swift                     ← swift-tools-version:5.9, iOS 16
├── README.md
├── AGENTS.md
└── .github/
    ├── CONTEXT.md                    ← this file
    ├── instructions/
    │   └── awflickrservices.instructions.md
    └── workflows/
        └── ios.yml                   ← CI: build + test on macos-15
```

---

## Public API surface

### Protocols (mixin pattern — conform in a UIViewController)

| Protocol | Requires also | Key method |
|---|---|---|
| `FlickrOAuthProtocol` | `ASWebAuthenticationPresentationContextProviding` | `performOAuthFlow(from:apiKey:apiSecret:callbackUrlString:completion:)` |
| `FlickrPhotosProtocol` | — | `getPhotos`, `getImage`, `getInfo`, `getComments`, `fave`, `unfave`, `comment` |

### FlickrPhotosProtocol methods

| Method | Auth required | Returns |
|---|---|---|
| `getPhotos(apiKey:photosRequest:completion:)` | No | `[FlickrPhoto]` |
| `getImage(from:completion:)` | No | `UIImage` (`returnCacheDataElseLoad`) |
| `getInfo(apiKey:infoRequest:completion:)` | No | `FlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:completion:)` | No | `[String]` (comment bodies) |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:completion:)` | Yes (OAuth) | `Void` |
| `unfave(...)` | Yes (OAuth) | `Void` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:completion:)` | Yes (OAuth) | `Void` |

### Public models

| Type | Fields |
|---|---|
| `FlickrPhoto` | `id`, `secret`, `title`, `owner`, `server`, `farm`; `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` (**Int in v2**) |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner`, `.dates: Dates`, `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError`, `.downloadImageError`, `.missingDataError` |

---

## Architecture invariants

- **Protocol mixin pattern** — `FlickrOAuthProtocol` and `FlickrPhotosProtocol` provide
  default implementations via `extension`. Consumers just conform and call.
- **Zero external dependencies** — `Package.swift` has no remote package dependencies.
- **UIKit dependency** — iOS-only. Do not make cross-platform without significant refactoring.
- **Completion-handler API** — all async operations use `@escaping (Result<T, Error>) -> Void`.
  Callbacks fire on the URLSession background queue. Callers must dispatch to main for UI.
- **OAuth 1.0a HMAC-SHA1** — signing key is `apiSecret&oauthTokenSecret`
  (empty secret for the request-token step → `apiSecret&`).
- **HTTP validation** — all `dataTask` completions check `200..<300`; non-2xx → `.networkError`.
- **`FlickrAPIRepository` is injected** — `init(session:)` defaults to `.shared`; 
  pass a stubbed session for unit testing.

---

## Tests (17 passing)

| Suite | Tests |
|---|---|
| `FlickrEndpointsTests` | 2 |
| `FlickrPhotoTests` | 2 |
| `FlickrPhotosRequestTests` | 1 |
| `FlickrModelsDecodingTests` | 4 |
| `FlickrAPIRepositoryURLBuildingTests` | 8 |

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
1e73143   fix(v2): public FlickrPhoto fields, HMAC utf8 byte count, add URL-building tests for getComments/fave/unfave/comment
2bb25d5   fix(v2): audit fixes — Equatable error, public photo_id, nil-URL completions, OAuthProtocol consistency, test tearDown, remove obsolete Linux test files, README v2
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


> Authoritative AI session state. Always read this before making changes.
> Update at the end of every session that touches code.

---

## Overview

A dependency-free Swift Package (SPM) for integrating the Flickr API in iOS apps.
Covers OAuth 1.0a (three-legged flow) and core Flickr REST methods via a
protocol-mixin design pattern — consumers conform to `FlickrOAuthProtocol` or
`FlickrPhotosProtocol` in their view controllers and call the default-implemented
methods directly.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **Version:** 1.0.0
- **Xcode:** 11.5+ (built and tested up to current)
- **Platform:** iOS 13+
- **Swift tools version:** 5.2

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer (URLSession)
│   ├── FlickrEndpoints.swift         ← Internal URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models
│   ├── FlickrOAuthModels.swift       ← Internal + public OAuth token models
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← Internal HMAC-SHA1 signing utilities
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← Placeholder only (no real tests yet)
├── Package.swift
└── README.md
```

---

## Public API surface

### Protocols (mixin pattern — conform in a UIViewController)

| Protocol | Requires also | Key method |
|---|---|---|
| `FlickrOAuthProtocol` | `ASWebAuthenticationPresentationContextProviding` | `performOAuthFlow(from:apiKey:apiSecret:callbackUrlString:completion:)` |
| `FlickrPhotosProtocol` | — | `getPhotos`, `getImage`, `getInfo`, `getComments`, `fave`, `unfave`, `comment` |

### FlickrPhotosProtocol methods

| Method | Auth required | Returns |
|---|---|---|
| `getPhotos(apiKey:photosRequest:completion:)` | No | `[FlickrPhoto]` |
| `getImage(from:completion:)` | No | `UIImage` (URLSession HTTP cache) |
| `getInfo(apiKey:infoRequest:completion:)` | No | `FlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:completion:)` | No | `[String]` (comment bodies) |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:completion:)` | Yes (OAuth) | `Void` |
| `unfave(...)` | Yes (OAuth) | `Void` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:completion:)` | Yes (OAuth) | `Void` |

### Public models

| Type | Fields |
|---|---|
| `FlickrPhoto` | `id`, `secret`, `title`, `owner`, `server`, `farm`; `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: String`, `per_page: String` |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner`, `.dates: Dates`, `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError`, `.downloadImageError`, `.missingDataError` |

### Internal types (not public)

- `FlickrAPIRepository` — concrete URLSession-based HTTP layer called by protocol extensions
- `FlickrEndpoints` — URL string constants and Flickr method names
- `RequestTokenResponse` — intermediate OAuth request token struct
- All free functions in `FlickrOAuthUtilities.swift` — HMAC-SHA1 signing, URL encoding

---

## Architecture invariants

- **Protocol mixin pattern** — `FlickrOAuthProtocol` and `FlickrPhotosProtocol` provide
  default implementations via `extension`. Consumers just conform and call; no
  subclassing or injection needed.
- **Zero external dependencies** — `Package.swift` has no remote package dependencies.
  Internal crypto uses `CommonCrypto` (system framework; no import needed in Package.swift
  because it is available on all Apple platforms).
- **UIKit dependency** — `FlickrAPIRepository` and `FlickrPhotosProtocol` import `UIKit`
  (`UIImage`, `UIViewController`). This makes the package iOS-only.
- **Completion-handler API** — all async operations use `@escaping (Result<T, Error>) -> Void`.
  No async/await.
- **OAuth 1.0a HMAC-SHA1** — signature is computed in `FlickrOAuthUtilities`. The signing
  key is `apiSecret&oauthTokenSecret` (empty secret for request-token step).
- **Flickr photo URL construction** — `FlickrPhoto.thumbnailPhotoURLString()` and
  `largePhotoURLString()` use the `farm-server-id-secret` URL template from `FlickrEndpoints`.
- **`FlickrPhotosRequest.page` and `per_page` are `String`** — not `Int`. Pass numeric
  strings (e.g., `"1"`, `"20"`).

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
