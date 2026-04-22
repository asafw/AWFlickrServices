# AWFlickrServices — Integration Guide

A dependency-free Swift Package (SPM) for the Flickr API.  
Supports **iOS 16+** and **macOS 12+**. No UIKit dependency.

---

## Table of contents

1. [Adding the package](#1-adding-the-package)
2. [Architecture: the mixin pattern](#2-architecture-the-mixin-pattern)
3. [Getting a Flickr API key](#3-getting-a-flickr-api-key)
4. [FlickrPhotosProtocol — unauthenticated methods](#4-flickrphotosprotocol--unauthenticated-methods)
   - [getPhotos](#getphotos)
   - [downloadImageData](#downloadimagedata)
   - [getInfo](#getinfo)
   - [getComments](#getcomments)
5. [FlickrOAuthProtocol — three-legged OAuth 1.0a](#5-flickroauthprotocol--three-legged-oauth-10a)
6. [FlickrPhotosProtocol — authenticated methods](#6-flickrphotosprotocol--authenticated-methods)
   - [fave / unfave](#fave--unfave)
   - [comment](#comment)
7. [Model types reference](#7-model-types-reference)
8. [Error handling](#8-error-handling)
9. [Thread safety](#9-thread-safety)
10. [Cross-platform notes](#10-cross-platform-notes)

---

## 1. Adding the package

### Xcode (recommended)

1. **File → Add Package Dependencies**
2. Paste `https://github.com/asafw/AWFlickrServices`
3. Select branch **`v2`** (or tag `2.0.0` once released)
4. Add **AWFlickrServices** to your target

### Package.swift

```swift
// swift-tools-version:5.9
dependencies: [
    .package(url: "https://github.com/asafw/AWFlickrServices", branch: "v2")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["AWFlickrServices"]
    )
]
```

No additional linker flags or framework search paths are needed. The package imports only
`Foundation`, `AuthenticationServices`, `CommonCrypto`, and `ObjectiveC` — all system-provided.

---

## 2. Architecture: the mixin pattern

AWFlickrServices uses **protocol mixins**: every method is declared in a protocol and
implemented in a `public extension`. Conforming your own type to a protocol makes all
methods available with zero boilerplate.

```
Your type
  └─ conforms to FlickrPhotosProtocol
       └─ inherits default implementations for all 7 methods
```

You never instantiate an AWFlickrServices object. There is no service layer to hold
onto. This keeps the package's footprint invisible inside your own architecture.

```swift
// Any Swift type works — class, struct, actor, even a SwiftUI view
struct PhotoRepository: FlickrPhotosProtocol {
    // All 7 FlickrPhotosProtocol methods are now available.
}
```

For lightweight usage you can even use a private nested struct at the call site:

```swift
private struct Service: FlickrPhotosProtocol {}
let service = Service()
service.getPhotos(apiKey: key, photosRequest: request) { result in … }
```

---

## 3. Getting a Flickr API key

1. Sign in at [flickr.com/services/apps/create](https://www.flickr.com/services/apps/create)
2. Apply for a non-commercial key (instant approval)
3. Note your **API Key** and **API Secret**
4. For OAuth: register a callback URL scheme (e.g. `myapp://flickr-oauth`)
   in the app's settings on the same page

Keep both values out of source control. In Xcode, pass them via an environment variable
or read them from the Keychain at runtime.

---

## 4. FlickrPhotosProtocol — unauthenticated methods

All methods below work without OAuth — your API Key is the only credential required.
Callbacks fire on the **URLSession background queue** (see [Thread safety](#9-thread-safety)).

### getPhotos

Search for photos matching a text query.

```swift
import AWFlickrServices

class SearchViewController: UIViewController, FlickrPhotosProtocol {

    func search(text: String) {
        let request = FlickrPhotosRequest(text: text, page: 1, per_page: 20)
        getPhotos(apiKey: "YOUR_API_KEY", photosRequest: request) { [weak self] result in
            switch result {
            case .success(let photos):
                // photos: [FlickrPhoto]
                DispatchQueue.main.async {
                    self?.updateUI(with: photos)
                }
            case .failure(let error):
                // See Error handling section for FlickrAPIError cases
                print("Search failed:", error)
            }
        }
    }
}
```

**Pagination** — increment `page` to fetch the next batch:

```swift
var currentPage = 1

func loadNextPage() {
    let request = FlickrPhotosRequest(text: "landscape", page: currentPage, per_page: 25)
    getPhotos(apiKey: apiKey, photosRequest: request) { [weak self] result in
        if case .success(let photos) = result {
            DispatchQueue.main.async {
                self?.allPhotos.append(contentsOf: photos)
                self?.currentPage += 1
            }
        }
    }
}
```

---

### downloadImageData

Downloads the bytes of a photo URL. The underlying `URLSession` is configured with
`.returnCacheDataElseLoad` — repeated calls for the same URL return the cached data
without hitting the network.

```swift
func loadThumbnail(for photo: FlickrPhoto) {
    guard let url = URL(string: photo.thumbnailPhotoURLString()) else { return }

    downloadImageData(from: url) { [weak self] result in
        switch result {
        case .success(let data):
            DispatchQueue.main.async {
                self?.imageView.image = UIImage(data: data)   // or NSImage on macOS
            }
        case .failure:
            // Network error — optionally show placeholder
            break
        }
    }
}
```

**Full-size photo** — swap `thumbnailPhotoURLString()` for `largePhotoURLString()`:

```swift
guard let url = URL(string: photo.largePhotoURLString()) else { return }
downloadImageData(from: url) { result in … }
```

---

### getInfo

Fetches metadata for a single photo: owner name and location, date taken, and view count.

```swift
func loadPhotoInfo(photo: FlickrPhoto) {
    let request = FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
    getInfo(apiKey: apiKey, infoRequest: request) { result in
        switch result {
        case .success(let response):
            // response.photo.owner.realname  → String
            // response.photo.owner.location  → String?  (nil if not set)
            // response.photo.dates.taken     → String  ("2021-07-04 12:00:00")
            // response.photo.views           → String  (numeric, e.g. "4821")
            print("Taken by:", response.photo.owner.realname)
        case .failure(let error):
            print("getInfo failed:", error)
        }
    }
}
```

---

### getComments

Fetches the text of all comments on a photo. Returns `[String]` — the `_content` field
from each Flickr comment object.

```swift
func loadComments(photo: FlickrPhoto) {
    let request = FlickrCommentsRequest(photo_id: photo.id)
    getComments(apiKey: apiKey, commentsRequest: request) { result in
        switch result {
        case .success(let comments):
            // comments: [String]
            comments.forEach { print($0) }
        case .failure(let error):
            print("getComments failed:", error)
        }
    }
}
```

---

## 5. FlickrOAuthProtocol — three-legged OAuth 1.0a

OAuth is required for write operations (`fave`, `unfave`, `comment`).
`performOAuthFlow` runs the full three-legged flow:

1. Gets a request token from Flickr
2. Opens the Flickr authorization page in an `ASWebAuthenticationSession`
3. Exchanges the verifier for an access token
4. Calls back with the `AccessTokenResponse` containing `oauth_token` and `oauth_token_secret`

### iOS

On iOS, a `UIViewController` is a convenient host. Conform it to both
`FlickrOAuthProtocol` and `ASWebAuthenticationPresentationContextProviding`:

```swift
import AWFlickrServices
import AuthenticationServices

class AuthViewController: UIViewController,
                          FlickrOAuthProtocol,
                          ASWebAuthenticationPresentationContextProviding {

    // Stored securely (e.g. Keychain) after a successful sign-in
    private var oauthToken: String = ""
    private var oauthTokenSecret: String = ""

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }

    func signIn() {
        performOAuthFlow(
            from: self,                          // self satisfies ASWebAuth...Providing
            apiKey: "YOUR_API_KEY",
            apiSecret: "YOUR_API_SECRET",
            callbackUrlString: "myapp://flickr-oauth"
        ) { [weak self] result in
            switch result {
            case .success(let response):
                // Persist these securely — required for fave / unfave / comment
                self?.oauthToken       = response.oauth_token
                self?.oauthTokenSecret = response.oauth_token_secret
                print("Signed in as:", response.username)
            case .failure(let error):
                print("OAuth failed:", error)
            }
        }
    }
}
```

### macOS

On macOS, supply a `PresentationContext` that returns the app's key window:

```swift
import AppKit
import AuthenticationServices

final class PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSWindow()
    }
}
```

Then call `performOAuthFlow` from anywhere that also conforms to `FlickrOAuthProtocol`:

```swift
class AppController: FlickrOAuthProtocol {

    private let context = PresentationContext()

    func signIn() {
        performOAuthFlow(
            from: context,
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: "myapp://flickr-oauth"
        ) { result in … }
    }
}
```

### Persisting the access token

Store `oauth_token` and `oauth_token_secret` in the Keychain between sessions.
Both are required for every OAuth-protected call.

```swift
// After a successful performOAuthFlow:
KeychainHelper.save(response.oauth_token,       forKey: "flickr_token")
KeychainHelper.save(response.oauth_token_secret, forKey: "flickr_token_secret")
```

---

## 6. FlickrPhotosProtocol — authenticated methods

All three methods below require the `oauth_token` and `oauth_token_secret` obtained in
the OAuth flow.

### fave / unfave

```swift
func toggleFave(photo: FlickrPhoto, isFaved: Bool) {
    let request = FlickrFaveRequest(photo_id: photo.id)

    let action: (String, String, String, String, FlickrFaveRequest,
                 @escaping (Result<Void, Error>) -> Void) -> Void =
        isFaved ? unfave : fave

    action(apiKey, apiSecret, oauthToken, oauthTokenSecret, request) { result in
        switch result {
        case .success:
            print(isFaved ? "Unfaved" : "Faved")
        case .failure(let error):
            print("Fave/unfave failed:", error)
        }
    }
}
```

Or call each separately:

```swift
// Fave
fave(
    apiKey: apiKey,
    apiSecret: apiSecret,
    oauthToken: oauthToken,
    oauthTokenSecret: oauthTokenSecret,
    faveRequest: FlickrFaveRequest(photo_id: photo.id)
) { result in
    if case .failure(let error) = result { print("Fave failed:", error) }
}

// Unfave
unfave(
    apiKey: apiKey,
    apiSecret: apiSecret,
    oauthToken: oauthToken,
    oauthTokenSecret: oauthTokenSecret,
    faveRequest: FlickrFaveRequest(photo_id: photo.id)
) { result in
    if case .failure(let error) = result { print("Unfave failed:", error) }
}
```

### comment

```swift
func postComment(text: String, on photo: FlickrPhoto) {
    let request = FlickrCommentRequest(photo_id: photo.id, comment_text: text)
    comment(
        apiKey: apiKey,
        apiSecret: apiSecret,
        oauthToken: oauthToken,
        oauthTokenSecret: oauthTokenSecret,
        commentRequest: request
    ) { result in
        switch result {
        case .success:
            print("Comment posted")
        case .failure(let error):
            print("Comment failed:", error)
        }
    }
}
```

---

## 7. Model types reference

### FlickrPhoto

```swift
public struct FlickrPhoto: Decodable, Sendable {
    public let id: String
    public let owner: String?   // owner NSID — present in faves responses
    public let secret: String
    public let server: String
    public let farm: Int
    public let title: String

    public func thumbnailPhotoURLString() -> String  // 75×75 px square thumbnail
    public func largePhotoURLString() -> String      // up to 1024px on longest side
}
```

### FlickrPhotosRequest

```swift
public struct FlickrPhotosRequest: Encodable, Sendable {
    public let text: String
    public let page: Int       // 1-based
    public let per_page: Int   // max 500 per Flickr API limits
}
```

### FlickrInfoResponse

```swift
public struct FlickrInfoResponse: Decodable, Sendable {
    public let photo: PhotoInfo
}

public struct PhotoInfo: Decodable, Sendable {
    public let owner: Owner
    public let dates: Dates
    public let views: String    // numeric string, e.g. "42153"
}

public struct Owner: Decodable, Sendable {
    public let realname: String
    public let location: String?   // nil if owner hasn't set a location
}

public struct Dates: Decodable, Sendable {
    public let taken: String   // "YYYY-MM-DD HH:MM:SS"
}
```

### FlickrFaveRequest

```swift
public struct FlickrFaveRequest: Encodable, Sendable {
    public let photo_id: String
}
```

### FlickrCommentRequest

```swift
public struct FlickrCommentRequest: Encodable, Sendable {
    public let photo_id: String
    public let comment_text: String
}
```

### FlickrInfoRequest

```swift
public struct FlickrInfoRequest: Encodable, Sendable {
    public let photo_id: String
    public let secret: String
}
```

### FlickrCommentsRequest

```swift
public struct FlickrCommentsRequest: Encodable, Sendable {
    public let photo_id: String
}
```

### AccessTokenResponse

```swift
public struct AccessTokenResponse: Decodable, Sendable {
    public let fullname: String
    public let oauth_token: String
    public let oauth_token_secret: String
    public let user_nsid: String
    public let username: String
}
```

---

## 8. Error handling

All completion handlers deliver `Result<T, Error>`. Cast to `FlickrAPIError` to handle
each case:

```swift
} case .failure(let error):
    if let flickrError = error as? FlickrAPIError {
        switch flickrError {
        case .networkError:
            // Non-2xx HTTP response, or the server was unreachable.
            // Retry logic or "Check your connection" message appropriate here.
            showAlert("Network error. Please try again.")

        case .parsingError:
            // The server returned data that couldn't be decoded.
            // Usually indicates an API change — file a bug.
            print("Parsing error — unexpected server response")

        case .apiError(let code, let message):
            // Flickr returned HTTP 200 with {"stat":"fail","code":N,"message":"..."}.
            // Common codes:
            //   1  — Photo not found
            //   2  — Photo is not in faves (unfave with no existing fave)
            //   100 — Invalid API Key
            //   105 — Service currently unavailable
            print("Flickr error \(code): \(message)")
        }
    }
```

`FlickrAPIError` conforms to `Equatable`, so you can compare cases directly in unit tests:

```swift
XCTAssertEqual(error as? FlickrAPIError, .networkError)
XCTAssertEqual(error as? FlickrAPIError, .apiError(code: 100, message: "Invalid API Key (Key has invalid format)"))
```

---

## 9. Thread safety

All network callbacks fire on the **URLSession background queue**, not the main thread.
Always dispatch UI updates to the main queue:

```swift
getPhotos(apiKey: apiKey, photosRequest: request) { [weak self] result in
    // ⚠️ This closure runs on a background thread
    if case .success(let photos) = result {
        DispatchQueue.main.async {
            // ✅ Safe to update UI here
            self?.photos = photos
            self?.tableView.reloadData()
        }
    }
}
```

In SwiftUI using `@MainActor` will guarantee safety without explicit dispatch:

```swift
@MainActor
func performSearch(text: String) async {
    await withCheckedContinuation { continuation in
        getPhotos(apiKey: apiKey, photosRequest: FlickrPhotosRequest(text: text, page: 1, per_page: 20)) { result in
            continuation.resume(returning: result)
        }
    }
    // Back on main actor — safe to mutate @Published / @State
}
```

---

## 10. Cross-platform notes

AWFlickrServices has no UIKit dependency. `downloadImageData` returns `Data` — convert
to the platform image type yourself:

```swift
// iOS / tvOS / watchOS
let image = UIImage(data: data)

// macOS
let image = NSImage(data: data)

// SwiftUI (both platforms via PlatformImage typealias)
typealias PlatformImage = NSImage   // or UIImage on iOS
let image = PlatformImage(data: data)
Image(nsImage: image)   // or Image(uiImage:)
```

### `ASWebAuthenticationSession` presentation context

| Platform | Recommended approach |
|---|---|
| iOS | Conform `UIViewController` to `ASWebAuthenticationPresentationContextProviding`; return `view.window` |
| macOS | Dedicated `PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding` that returns `NSApp.keyWindow` |
| SwiftUI (both) | Inject a `PresentationContext` object; use `#if canImport(AppKit)` / `canImport(UIKit)` to provide the right window |

The `Examples/FlickrDemoApp/PresentationContext.swift` file in this repository contains
a ready-to-copy cross-platform implementation.
