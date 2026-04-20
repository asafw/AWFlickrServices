---
applyTo: "**"
---

# AWFlickrServices — Copilot Instructions

> Maintained automatically. Update via `.github/CONTEXT.md` + `AGENTS.md`
> and re-sync this file at the end of each session.

## Project overview

A dependency-free Swift Package for integrating the Flickr API in iOS apps.
Uses a **protocol mixin pattern**: consumers conform to `FlickrOAuthProtocol`
or `FlickrPhotosProtocol` in their view controllers and gain full API access
through protocol extension default implementations. No subclassing or object
injection required.

Originally written in 2020. iOS 13+, completion-handler API, zero external
dependencies.

- **Repo:** `asafw/AWFlickrServices` (public) — `~/Desktop/asafw/AWFlickrServices/`
- **Authoritative state:** `.github/CONTEXT.md` — always read before making changes.

---

## Repository layout

```
AWFlickrServices/
├── Sources/AWFlickrServices/
│   ├── FlickrAPIError.swift          ← Public error enum
│   ├── FlickrAPIRepository.swift     ← Internal HTTP layer (URLSession)
│   ├── FlickrEndpoints.swift         ← Internal URL / Flickr method constants
│   ├── FlickrModels.swift            ← Public request & response models
│   ├── FlickrOAuthModels.swift       ← OAuth token models (partially public)
│   ├── FlickrOAuthProtocol.swift     ← Public OAuth protocol + default impl
│   ├── FlickrOAuthUtilities.swift    ← Internal HMAC-SHA1 signing utilities
│   └── FlickrPhotosProtocol.swift    ← Public photos protocol + default impl
├── Tests/AWFlickrServicesTests/
│   └── AWFlickrServicesTests.swift   ← Placeholder (no real tests yet)
├── Package.swift
├── README.md
└── AGENTS.md
```

---

## Types and APIs

### Protocols

| Protocol | Inherits from | Purpose |
|---|---|---|
| `FlickrOAuthProtocol` | — | Drives three-legged OAuth 1.0a flow |
| `FlickrPhotosProtocol` | — | Photo search, image download, fave/unfave/comment |

Both protocols use the **mixin pattern**: implement the method signature in the
protocol; provide the full implementation in a `public extension`. Conforming
types get all behaviour for free.

`FlickrOAuthProtocol` requires the conforming UIViewController to also conform
to `ASWebAuthenticationPresentationContextProviding`.

### FlickrPhotosProtocol methods

| Method | OAuth required | Return type |
|---|---|---|
| `getPhotos(apiKey:photosRequest:completion:)` | No | `[FlickrPhoto]` |
| `getImage(from:completion:)` | No | `UIImage` |
| `getInfo(apiKey:infoRequest:completion:)` | No | `FlickrInfoResponse` |
| `getComments(apiKey:commentsRequest:completion:)` | No | `[String]` |
| `fave(apiKey:apiSecret:oauthToken:oauthTokenSecret:faveRequest:completion:)` | Yes | `Void` |
| `unfave(...)` | Yes | `Void` |
| `comment(apiKey:apiSecret:oauthToken:oauthTokenSecret:commentRequest:completion:)` | Yes | `Void` |

### Public models

| Type | Key fields / notes |
|---|---|
| `FlickrPhoto` | `id`, `secret`, `title`, `farm`, `server`; URL helpers: `thumbnailPhotoURLString()`, `largePhotoURLString()` |
| `FlickrPhotosRequest` | `text: String`, `page: String`, `per_page: String` — **page and per_page are String, not Int** |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrInfoResponse` | `.photo: PhotoInfo` → `.owner: Owner` (realname, location?), `.dates: Dates` (taken), `.views: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `AccessTokenResponse` | `fullname`, `oauth_token`, `oauth_token_secret`, `user_nsid`, `username` |
| `FlickrAPIError` | `.parsingError`, `.networkError`, `.downloadImageError`, `.missingDataError` |

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
- **UIKit dependency** — `UIImage` and `UIViewController` are used throughout.
  The package is intentionally iOS-only. Do not attempt to make it cross-platform
  without significant refactoring.
- **Completion-handler API** — all async network calls use
  `@escaping (Result<T, Error>) -> Void`. Callbacks fire on the URLSession
  background queue. Callers must dispatch to the main queue for UI updates.
- **OAuth 1.0a HMAC-SHA1** — signing key is `"apiSecret&oauthTokenSecret"`.
  For the request-token step, `oauthTokenSecret` is empty (`""`), so the key
  is `"apiSecret&"`. This is correct per the OAuth 1.0a spec.
- **`FlickrPhotosRequest.page` / `per_page` are `String`** — this is a known
  quirk. Do not change them to `Int` without also updating `FlickrAPIRepository`
  (which currently passes them as strings in URL query params).
- **`FlickrPhotosurlTemplate`** — thumbnail uses `_s` suffix (small square, 75×75),
  large uses `_b` suffix (large, 1024px). Both follow the Flickr static URL scheme:
  `https://farmN.staticflickr.com/server/id_secret_size.jpg`.

---

## Coding conventions

- **All source files stay in `Sources/AWFlickrServices/`** — do not split into
  subdirectories unless the file count becomes unmanageable.
- **No imports beyond system frameworks** — `UIKit`, `AuthenticationServices`,
  `Foundation` (implicit), `CommonCrypto`.
- **Doc comments** — every `public` type and method should have a `///` doc comment.
- **Tests** — any new public method must have a corresponding test.
  `FlickrAPIRepository` needs a `URLSession` injection seam before it can be
  unit-tested; add one when writing tests rather than making live network calls.
- **`@discardableResult` not needed** — these are all completion-handler APIs.

---

## Build and test

```bash
swift build
swift test
```

---

## Session end checklist

1. Run `swift test` — all tests must pass.
2. Update `.github/CONTEXT.md`: latest commit hash, test counts, changed APIs.
3. Update this file if architecture, conventions, or type descriptions changed.
4. Commit both together:
   ```bash
   git add .github/CONTEXT.md .github/instructions/awflickrservices.instructions.md
   git commit -m "docs(context): update session state"
   git push origin master
   ```
