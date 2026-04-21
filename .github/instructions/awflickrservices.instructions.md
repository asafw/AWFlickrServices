---
applyTo: "**"
---

# AWFlickrServices — Copilot Instructions

> Maintained automatically. Update via `.github/CONTEXT.md` + `AGENTS.md`
> and re-sync this file at the end of each session.

## Project overview

A dependency-free Swift Package for integrating the Flickr API in iOS and macOS apps.
Uses a **protocol mixin pattern**: consumers conform to `FlickrOAuthProtocol`
or `FlickrPhotosProtocol` and gain full API access through protocol extension
default implementations. No subclassing or object injection required.

Originally written in 2020. v2.0 (2026): iOS 16+ / macOS 12+, completion-handler API,
zero external dependencies, no UIKit dependency.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **Active branch:** `v2` — all development here; `master` frozen at v1.0.0
- **Authoritative state:** `.github/CONTEXT.md` — always read before making changes.

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum (parsingError, networkError, apiError)
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer; decodeFlickrJSON checks stat:fail before decode
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← HMAC-SHA1 signing; rfc3986Encoded + hmacsha1EncryptedString are internal
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 51 unit tests (8 suites, CapturingURLProtocol stub)
├── Tests/AWFlickrServicesIntegrationTests/
│   └── AWFlickrServicesIntegrationTests.swift  ← 16 live tests; skip without credentials
├── Package.swift                     ← swift-tools-version:5.9, iOS 16+, macOS 12+; 3 targets
├── README.md
└── AGENTS.md
```

---

## Types and APIs

### Protocols

| Protocol | Inherits from | Purpose |
|---|---|---|
| `FlickrOAuthProtocol` | — | Drives three-legged OAuth 1.0a flow |
| `FlickrPhotosProtocol` | — | Photo search, image data download, fave/unfave/comment |

Both protocols use the **mixin pattern**: implement the method signature in the
protocol; provide the full implementation in a `public extension`. Conforming
types get all behaviour for free.

`FlickrOAuthProtocol.performOAuthFlow(from:...)` takes an
`ASWebAuthenticationPresentationContextProviding` directly — works on both iOS
and macOS. The `ASWebAuthenticationSession` is retained via
`objc_setAssociatedObject` on the context object so it survives until the
callback fires.

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
| `FlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; URL helpers: `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` — **Int in v2** |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner` (realname, location?), `.dates: Dates` (taken), `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError`, `.apiError(code: Int, message: String)` |

### Internal types (do not expose publicly)

- `FlickrAPIRepository` — concrete `URLSession`-based HTTP implementation; `init(session:)` injects the session
- `FlickrEndpoints` — all URL templates and Flickr REST method strings
- `RequestTokenResponse` — intermediate OAuth model
- `FlickrErrorEnvelope` — private struct in `FlickrAPIRepository.swift` for `stat:fail` detection
- `rfc3986Encoded(_:)` and `hmacsha1EncryptedString(string:key:)` in `FlickrOAuthUtilities.swift` — `internal` (not `public`)

---

## Architecture invariants

- **Zero external dependencies** — `Package.swift` must stay dependency-free.
  `CommonCrypto` is available system-wide on Apple platforms.
- **No UIKit dependency** — iOS 16+ and macOS 12+. `downloadImageData(from:completion:)`
  returns `Data`; callers convert to `UIImage`/`NSImage` themselves.
- **Completion-handler API** — all async network calls use
  `@escaping (Result<T, Error>) -> Void`. Callbacks fire on the URLSession
  background queue. Callers must dispatch to the main queue for UI updates.
- **`stat:fail` detection** — `decodeFlickrJSON<T>` checks for `{"stat":"fail",...}` before
  attempting the real type decode and throws `FlickrAPIError.apiError(code:message:)`.
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
  The conversion to string is done internally inside `FlickrAPIRepository`.
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
- **`@discardableResult` not needed** — these are all completion-handler APIs.

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Unit tests (fast, no network)
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" -only-testing:AWFlickrServicesTests test
# All tests including integration (requires /tmp/flickr_api_key)
xcodebuild -scheme AWFlickrServices -destination "platform=macOS" test
```

> `swift build` / `swift test` will fail with "no such module 'AuthenticationServices'" on
> macOS CLI — always use `xcodebuild`.

---

## Session end checklist

1. Run unit tests — all 51 must pass.
2. Update `.github/CONTEXT.md`: latest commit hash, test counts, any changed APIs.
3. Update this file if architecture, conventions, or type descriptions changed.
4. Commit both together:
   ```bash
   git add .github/CONTEXT.md .github/instructions/awflickrservices.instructions.md
   git commit -m "docs(context): update session state"
   git push origin v2
   ```


---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum (parsingError, networkError)
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer (URLSession injection seam)
│   ├── FlickrEndpoints.swift         ← Internal caseless enum of URL / method constants
│   ├── FlickrModels.swift            ← Public request & response models (Sendable)
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← Internal HMAC-SHA1 signing utilities (Foundation + CommonCrypto)
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← 34 unit tests (7 suites, URLProtocol stub)
├── Package.swift                     ← swift-tools-version:5.9, iOS 16+, macOS 12+
├── README.md
└── AGENTS.md
```

---

## Types and APIs

### Protocols

| Protocol | Inherits from | Purpose |
|---|---|---|
| `FlickrOAuthProtocol` | — | Drives three-legged OAuth 1.0a flow |
| `FlickrPhotosProtocol` | — | Photo search, image data download, fave/unfave/comment |

Both protocols use the **mixin pattern**: implement the method signature in the
protocol; provide the full implementation in a `public extension`. Conforming
types get all behaviour for free.

`FlickrOAuthProtocol.performOAuthFlow(from:...)` takes an
`ASWebAuthenticationPresentationContextProviding` directly — works on both iOS
and macOS. The `ASWebAuthenticationSession` is retained via
`objc_setAssociatedObject` on the context object so it survives until the
callback fires.

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
| `FlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; URL helpers: `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` — **Int in v2** |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner` (realname, location?), `.dates: Dates` (taken), `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError` |

### Internal types (do not expose publicly)

- `FlickrAPIRepository` — concrete `URLSession.shared`-based HTTP implementation
- `FlickrEndpoints` — all URL templates and Flickr REST method strings
- `RequestTokenResponse` — intermediate OAuth model
- Free functions in `FlickrOAuthUtilities.swift` — HMAC-SHA1 signing, OAuth
  parameter assembly, URL percent-encoding

---

## Architecture invariants

- **Zero external dependencies** — `Package.swift` must stay dependency-free.
  `CommonCrypto` is available system-wide on Apple platforms; no special
  declaration needed in `Package.swift`.
- **No UIKit dependency** — iOS 16+ and macOS 12+. `downloadImageData(from:completion:)`
  returns `Data`; callers convert to `UIImage`/`NSImage` themselves.
- **Completion-handler API** — all async network calls use
  `@escaping (Result<T, Error>) -> Void`. Callbacks fire on the URLSession
  background queue. Callers must dispatch to the main queue for UI updates.
- **OAuth 1.0a HMAC-SHA1** — signing key is `"apiSecret&oauthTokenSecret"`.
  For the request-token step, `oauthTokenSecret` is empty (`""`), so the key
  is `"apiSecret&"`. This is correct per the OAuth 1.0a spec.
- **RFC 3986 percent-encoding** — all OAuth parameter values are encoded using
  only the unreserved character set (`alphanumerics ∪ "-._~"`). The private
  `rfc3986Encoded(_:)` helper in `FlickrOAuthUtilities.swift` implements this.
- **Alphanumeric OAuth nonce** — `UUID().uuidString` with hyphens stripped.
- **`FlickrPhotosRequest.page` / `per_page` are `Int`** (v2 — changed from `String` in v1).
  The conversion to string is done internally inside `FlickrAPIRepository`.
- **`Comment.content`** — the Flickr JSON field `_content` is decoded via `CodingKeys`
  into the Swift-idiomatic property name `content`. Do not revert to `_content`.

---

## Coding conventions

- **All source files stay in `Sources/AWFlickrServices/`** — do not split into
  subdirectories unless the file count becomes unmanageable.
- **No imports beyond system frameworks** — `AuthenticationServices`,
  `Foundation`, `CommonCrypto`, `ObjectiveC`. `UIKit` has been removed.
- **Doc comments** — every `public` type and method should have a `///` doc comment.
- **Tests** — any new public method must have a corresponding test.
  Use `CapturingURLProtocol: URLProtocol` (already in the test file) as the
  URLSession stub — no live network, no simulator I/O needed.
- **`@discardableResult` not needed** — these are all completion-handler APIs.

---

## Build and test

```bash
cd ~/Desktop/asafw/AWFlickrServices
# Build
xcodebuild -scheme AWFlickrServices -destination "generic/platform=iOS Simulator" build
# Test
xcodebuild -scheme AWFlickrServices -destination "platform=iOS Simulator,name=iPhone 16" test
```

> `swift build` / `swift test` will fail with "no such module 'AuthenticationServices'" on
> macOS CLI — always use `xcodebuild` with an iOS Simulator destination.

---

## Session end checklist

1. Run `swift test` — all tests must pass.
2. Update `.github/CONTEXT.md`: latest commit hash, test counts, changed APIs.
3. Update this file if architecture, conventions, or type descriptions changed.
4. Commit both together:
   ```bash
   git add .github/CONTEXT.md .github/instructions/awflickrservices.instructions.md
   git commit -m "docs(context): update session state"
   git push origin v2
   ```
