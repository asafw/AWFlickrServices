# AWFlickrServices

![CI](https://github.com/asafw/AWFlickrServices/actions/workflows/ios.yml/badge.svg)

A dependency-free Swift Package for integrating the Flickr API in iOS and macOS applications.
Uses a **protocol mixin pattern** — conform any Swift type to `FlickrOAuthProtocol`
or `FlickrPhotosProtocol` and get full API access through protocol extension default
implementations. No subclassing or dependency injection required.

## Version

* 2.0.0

## Requirements

* Xcode 16+ / Swift 5.9
* iOS 16+ **or** macOS 12+
* A Flickr API Key (and Secret for OAuth operations)

## Package capabilities

| Protocol | Methods | OAuth required |
|---|---|---|
| `FlickrPhotosProtocol` | `getPhotos`, `downloadImageData`, `getInfo`, `getComments` | No |
| `FlickrPhotosProtocol` | `fave`, `unfave`, `comment` | Yes |
| `FlickrOAuthProtocol` | `performOAuthFlow` | — (drives the sign-in flow) |

All public model types conform to `Sendable`.

## Migrating from v1

| v1 | v2 |
|---|---|
| `FlickrPhotosRequest(text:page:per_page:)` — `page`/`per_page` are `String` | `page`/`per_page` are `Int` |
| `Comment._content` | `Comment.content` |
| `getImage(from:completion:)` returns `UIImage` | `downloadImageData(from:completion:)` returns `Data` |
| iOS 13+ | iOS 16+ |

## Installation

In Xcode: **File → Add Package Dependencies**, paste the repository URL, and select the `v2` branch (or the `2.0.0` tag when released).

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/asafw/AWFlickrServices", branch: "v2")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AWFlickrServices"]
    )
]
```

---

## Architecture

AWFlickrServices uses **protocol mixins**: every method is declared in a protocol and fully implemented in a `public extension`. Conforming your own type gives it all methods for free — no service object to hold onto, no initialiser to call.

```swift
// Any Swift type works
struct PhotoRepository: FlickrPhotosProtocol { }
let repo = PhotoRepository()
repo.getPhotos(apiKey: "KEY", photosRequest: request) { result in … }
```

For lightweight call-site usage a private nested type works too:

```swift
private struct Service: FlickrPhotosProtocol { }
Service().downloadImageData(from: url) { result in … }
```

---

## Data types

### Request types

| Type | Fields |
|---|---|
| `FlickrPhotosRequest` | `text: String`, `page: Int`, `per_page: Int` |
| `FlickrInfoRequest` | `photo_id: String`, `secret: String` |
| `FlickrCommentsRequest` | `photo_id: String` |
| `FlickrFaveRequest` | `photo_id: String` |
| `FlickrCommentRequest` | `photo_id: String`, `comment_text: String` |

All request types conform to `Encodable` and `Sendable`.

### Response types

#### `FlickrPhoto`

Returned in arrays from `getPhotos`.

```swift
public struct FlickrPhoto: Decodable, Sendable {
    public let id: String
    public let owner: String?   // owner NSID — present in faves responses
    public let secret: String
    public let server: String
    public let farm: Int
    public let title: String

    // URL helpers
    public func thumbnailPhotoURLString() -> String  // 75×75 px square
    public func largePhotoURLString() -> String      // up to 1024 px on longest side
}
```

Example:

```swift
let url = URL(string: photo.largePhotoURLString())
// → "https://farm4.staticflickr.com/3/12345678_abcdef00_b.jpg"
```

#### `FlickrInfoResponse`

Returned from `getInfo`.

```swift
public struct FlickrInfoResponse: Decodable, Sendable {
    public let photo: PhotoInfo
}

public struct PhotoInfo: Decodable, Sendable {
    public let owner: Owner
    public let dates: Dates
    public let views: String    // numeric string, e.g. "4821"
}

public struct Owner: Decodable, Sendable {
    public let realname: String
    public let location: String?   // nil if the owner hasn't set a location
}

public struct Dates: Decodable, Sendable {
    public let taken: String    // "YYYY-MM-DD HH:MM:SS"
}
```

#### `AccessTokenResponse`

Returned from `performOAuthFlow` on successful sign-in.

```swift
public struct AccessTokenResponse: Decodable, Sendable {
    public let fullname: String
    public let oauth_token: String
    public let oauth_token_secret: String
    public let user_nsid: String
    public let username: String
}
```

Persist `oauth_token` and `oauth_token_secret` (e.g. in the Keychain) — both are required for every authenticated call.

### `FlickrAPIError`

All completion handlers deliver `Result<T, Error>`. Cast to `FlickrAPIError` for structured handling:

```swift
public enum FlickrAPIError: Error, Equatable {
    case parsingError                      // unexpected server response shape
    case networkError                      // non-2xx HTTP status
    case apiError(code: Int, message: String)  // Flickr stat:fail (HTTP 200 with error body)
}
```

Common `apiError` codes:

| Code | Meaning |
|---|---|
| 1 | Photo not found |
| 2 | Photo is not in faves (unfave without a prior fave) |
| 100 | Invalid API Key |
| 105 | Service currently unavailable |

---

## Usage

All network callbacks fire on the **URLSession background queue**. Always dispatch UI updates to the main thread:

```swift
getPhotos(apiKey: apiKey, photosRequest: request) { [weak self] result in
    // ⚠️ background thread
    if case .success(let photos) = result {
        DispatchQueue.main.async { self?.photos = photos }
    }
}
```

---

### FlickrOAuthProtocol

`performOAuthFlow` runs the full three-legged OAuth 1.0a flow: request token → user authorization (in-app web sheet) → access token.

On iOS, conform a `UIViewController` to both `FlickrOAuthProtocol` and `ASWebAuthenticationPresentationContextProviding`:

```swift
import AWFlickrServices
import AuthenticationServices

class AuthViewController: UIViewController,
                          FlickrOAuthProtocol,
                          ASWebAuthenticationPresentationContextProviding {

    var oauthToken       = ""
    var oauthTokenSecret = ""

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }

    func signIn() {
        performOAuthFlow(
            from: self,
            apiKey: "YOUR_API_KEY",
            apiSecret: "YOUR_API_SECRET",
            callbackUrlString: "myapp://flickr-oauth"
        ) { [weak self] result in
            switch result {
            case .success(let response):
                self?.oauthToken       = response.oauth_token
                self?.oauthTokenSecret = response.oauth_token_secret
                print("Signed in as", response.username)
            case .failure(let error):
                print("Sign-in failed:", error)
            }
        }
    }
}
```

On macOS, supply a dedicated `PresentationContext` that returns `NSApp.keyWindow`. See [`Examples/FlickrDemoApp/PresentationContext.swift`](Examples/FlickrDemoApp/PresentationContext.swift) for a ready-to-copy cross-platform implementation.

---

### FlickrPhotosProtocol

#### getPhotos

Search for photos by keyword. Returns `[FlickrPhoto]`.

```swift
let request = FlickrPhotosRequest(text: "golden gate", page: 1, per_page: 25)
getPhotos(apiKey: apiKey, photosRequest: request) { result in
    switch result {
    case .success(let photos):
        // [FlickrPhoto] — use photo.id, .title, .thumbnailPhotoURLString(), etc.
        photos.forEach { print($0.title) }
    case .failure(let error as FlickrAPIError):
        switch error {
        case .networkError: print("Network error")
        case .apiError(let code, let msg): print("Flickr error \(code): \(msg)")
        default: break
        }
    case .failure(let error): print(error)
    }
}
```

**Pagination** — increment `page` to load the next batch:

```swift
var page = 1

func loadMore() {
    let request = FlickrPhotosRequest(text: "landscape", page: page, per_page: 25)
    getPhotos(apiKey: apiKey, photosRequest: request) { [weak self] result in
        if case .success(let photos) = result {
            DispatchQueue.main.async {
                self?.allPhotos.append(contentsOf: photos)
                self?.page += 1
            }
        }
    }
}
```

---

#### downloadImageData

Downloads raw image bytes from any URL. Uses `.returnCacheDataElseLoad` — repeated calls for the same URL skip the network. Returns `Data`; convert to `UIImage` / `NSImage` yourself.

```swift
guard let url = URL(string: photo.largePhotoURLString()) else { return }

downloadImageData(from: url) { result in
    switch result {
    case .success(let data):
        DispatchQueue.main.async {
            self.imageView.image = UIImage(data: data) // NSImage(data:) on macOS
        }
    case .failure:
        break // show placeholder
    }
}
```

Thumbnails use the same method — just call `photo.thumbnailPhotoURLString()` instead.

---

#### getInfo

Fetches metadata for a single photo: owner name and optional location, date taken, and total view count.

```swift
let request = FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
getInfo(apiKey: apiKey, infoRequest: request) { result in
    switch result {
    case .success(let response):
        print(response.photo.owner.realname)        // "Alice Smith"
        print(response.photo.owner.location ?? "")  // "Paris, France" or nil
        print(response.photo.dates.taken)           // "2021-07-04 12:30:00"
        print(response.photo.views)                 // "4821"
    case .failure(let error):
        print("getInfo failed:", error)
    }
}
```

---

#### getComments

Returns all comment texts on a photo as `[String]`.

```swift
let request = FlickrCommentsRequest(photo_id: photo.id)
getComments(apiKey: apiKey, commentsRequest: request) { result in
    switch result {
    case .success(let comments):
        comments.forEach { print($0) }   // plain text of each comment
    case .failure(let error):
        print("getComments failed:", error)
    }
}
```

---

#### fave / unfave *(OAuth required)*

```swift
let request = FlickrFaveRequest(photo_id: photo.id)

// Fave
fave(
    apiKey: apiKey, apiSecret: apiSecret,
    oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
    faveRequest: request
) { result in
    if case .failure(let error) = result { print("Fave failed:", error) }
}

// Unfave
unfave(
    apiKey: apiKey, apiSecret: apiSecret,
    oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
    faveRequest: request
) { result in
    if case .failure(let error) = result { print("Unfave failed:", error) }
}
```

Both return `Result<Void, Error>` — `.success(())` on success.

---

#### comment *(OAuth required)*

```swift
let request = FlickrCommentRequest(photo_id: photo.id, comment_text: "Great shot!")
comment(
    apiKey: apiKey, apiSecret: apiSecret,
    oauthToken: oauthToken, oauthTokenSecret: oauthTokenSecret,
    commentRequest: request
) { result in
    switch result {
    case .success:
        print("Comment posted")
    case .failure(let error):
        print("Comment failed:", error)
    }
}
```

---

## Demo App

A demo app under `Examples/` demonstrates all seven `FlickrPhotosProtocol` methods plus the full OAuth flow. The same SwiftUI source files run on both macOS and iOS.

### Screenshots

#### iOS

| Empty state | Signed in | Search results |
|:-----------:|:---------:|:--------------:|
| ![iOS empty state](screenshots/ios/ios_empty_state.png) | ![iOS signed in](screenshots/ios/ios_signed_in.png) | ![iOS search results](screenshots/ios/ios_search_results.png) |

| Photo detail | Authenticated search | Authenticated detail |
|:------------:|:--------------------:|:--------------------:|
| ![iOS photo detail](screenshots/ios/ios_photo_detail.png) | ![iOS authenticated search](screenshots/ios/ios_search_results_signed_in.png) | ![iOS authenticated detail](screenshots/ios/ios_photo_detail_authenticated.png) |

#### macOS

| Empty state | Search results | Photo detail |
|:-----------:|:--------------:|:------------:|
| ![macOS empty state](screenshots/macos/macos_empty_state.png) | ![macOS search results](screenshots/macos/macos_search_results.png) | ![macOS photo detail](screenshots/macos/macos_photo_detail.png) |

### Running on macOS

```bash
# Option 1 — environment variable (no files left on disk)
FLICKR_API_KEY=your_api_key swift run FlickrDemoApp

# Option 2 — credential file
echo "your_api_key" > /tmp/flickr_api_key
swift run FlickrDemoApp
```

Run from the package root (`AWFlickrServices/` directory).

### Running on iOS Simulator

```bash
cd Examples/FlickrDemoApp-iOS
xcodegen generate          # only needed once
open FlickrDemoApp-iOS.xcodeproj
```

In Xcode, set `FLICKR_API_KEY` in **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, then ⌘R. If the variable is absent an API Key field appears in the app UI.

Layout adapts automatically: VStack on iPhone, HStack sidebar on iPad and macOS.

---

## See also

[docs/INTEGRATION.md](docs/INTEGRATION.md) — full integration walkthrough with additional examples for pagination, cross-platform image handling, Keychain persistence, and `@MainActor` usage patterns.


## Version

* 2.0.0

## Prerequisites

* Xcode 16+
* Swift 5.9
* iOS 16+ **or** macOS 12+
* API Key and Secret obtained from Flickr

## Package capabilities

* OAuth 1.0a flow — Request Token, Authorization, Access Token
* Methods not requiring OAuth — `getPhotos`, `downloadImageData`, `getInfo`, `getComments`
* Methods requiring OAuth — `fave`, `unfave`, `comment`

All public model types conform to `Sendable`.

## Migrating from v1

| v1 | v2 |
|---|---|
| `FlickrPhotosRequest(text:page:per_page:)` — `page`/`per_page` are `String` | `page`/`per_page` are `Int` |
| `Comment._content` | `Comment.content` |
| iOS 13+ | iOS 16+ |

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**, paste the repository URL, and select the `v2` branch (or the `2.0.0` tag when released).

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/asafw/AWFlickrServices", branch: "v2")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["AWFlickrServices"]
    )
]
```

> For a complete integration walkthrough, model type reference, error handling patterns,
> and thread-safety notes, see **[docs/INTEGRATION.md](docs/INTEGRATION.md)**.

---

## Usage

### Naming conventions for code examples

```swift
apiKey           // API Key obtained from Flickr
apiSecret        // API Secret obtained from Flickr
callbackUrlString // Callback to your app, used in the OAuth authorization step
oauthToken       // OAuth access token obtained in the OAuth flow
oauthTokenSecret // OAuth access token secret obtained in the OAuth flow
```

### FlickrOAuthProtocol

Conform any class to `FlickrOAuthProtocol`. To trigger the OAuth web sheet you
also need an `ASWebAuthenticationPresentationContextProviding` — on iOS a
`UIViewController` is the most convenient host:

```swift
import AWFlickrServices
import AuthenticationServices

class ViewController: UIViewController, FlickrOAuthProtocol, ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
```

Call `performOAuthFlow` to run the full three-legged OAuth flow:

```swift
performOAuthFlow(
    from: self,
    apiKey: apiKey,
    apiSecret: apiSecret,
    callbackUrlString: callbackUrlString
) { response in
    switch response {
    case .success(let accessTokenResponse):
        // retain accessTokenResponse.oauth_token and .oauth_token_secret
    case .failure(let error):
        // handle error
    }
}
```

### FlickrPhotosProtocol

Conform any Swift type (class, struct, actor) to `FlickrPhotosProtocol`:

```swift
import AWFlickrServices

class ViewController: UIViewController, FlickrPhotosProtocol {
    // all FlickrPhotosProtocol methods are available via default implementations
}
```

**Get photos** (no OAuth required)

```swift
let photosRequest = FlickrPhotosRequest(text: searchText, page: 1, per_page: 20)
getPhotos(apiKey: apiKey, photosRequest: photosRequest) { response in
    switch response {
    case .success(let photos):
        // handle [FlickrPhoto]
    case .failure(let error):
        // handle error
    }
}
```

**Download image data** (no OAuth required — uses built-in HTTP cache)

```swift
if let url = URL(string: photo.largePhotoURLString()) {
    downloadImageData(from: url) { response in
        switch response {
        case .success(let data):
            // data is the raw bytes — convert to UIImage / NSImage as needed
            DispatchQueue.main.async {
                self.imageView.image = UIImage(data: data)
            }
        case .failure(let error):
            // handle error
        }
    }
}
```

**Get info** (no OAuth required)

```swift
let infoRequest = FlickrInfoRequest(photo_id: photoId, secret: photoSecret)
getInfo(apiKey: apiKey, infoRequest: infoRequest) { response in
    switch response {
    case .success(let infoResponse):
        // handle FlickrInfoResponse
    case .failure(let error):
        // handle error
    }
}
```

**Get comments** (no OAuth required)

```swift
let commentsRequest = FlickrCommentsRequest(photo_id: photoId)
getComments(apiKey: apiKey, commentsRequest: commentsRequest) { response in
    switch response {
    case .success(let comments):
        // handle [String]
    case .failure(let error):
        // handle error
    }
}
```

**Fave** (OAuth required)

```swift
let faveRequest = FlickrFaveRequest(photo_id: photoId)
fave(
    apiKey: apiKey,
    apiSecret: apiSecret,
    oauthToken: oauthToken,
    oauthTokenSecret: oauthTokenSecret,
    faveRequest: faveRequest
) { response in
    switch response {
    case .success:
        // handle success
    case .failure(let error):
        // handle error
    }
}
```

**Unfave** (OAuth required)

```swift
let faveRequest = FlickrFaveRequest(photo_id: photoId)
unfave(
    apiKey: apiKey,
    apiSecret: apiSecret,
    oauthToken: oauthToken,
    oauthTokenSecret: oauthTokenSecret,
    faveRequest: faveRequest
) { response in
    switch response {
    case .success:
        // handle success
    case .failure(let error):
        // handle error
    }
}
```

**Comment** (OAuth required)

```swift
let commentRequest = FlickrCommentRequest(photo_id: photoId, comment_text: commentText)
comment(
    apiKey: apiKey,
    apiSecret: apiSecret,
    oauthToken: oauthToken,
    oauthTokenSecret: oauthTokenSecret,
    commentRequest: commentRequest
) { response in
    switch response {
    case .success:
        // handle success
    case .failure(let error):
        // handle error
    }
}
```

## Demo App

A demo app included under `Examples/` demonstrates `FlickrPhotosProtocol` — searching
for photos, lazy-loading thumbnails, and fetching photo info and comments — without
writing any UIKit or AppKit code. The same SwiftUI source files run on both macOS and iOS.

### Screenshots

#### iOS

| Empty state | Signed in | Search results |
|:-----------:|:---------:|:--------------:|
| ![iOS empty state](screenshots/ios/ios_empty_state.png) | ![iOS signed in](screenshots/ios/ios_signed_in.png) | ![iOS search results](screenshots/ios/ios_search_results.png) |

| Photo detail | Authenticated search | Authenticated detail |
|:------------:|:--------------------:|:--------------------:|
| ![iOS photo detail](screenshots/ios/ios_photo_detail.png) | ![iOS authenticated search](screenshots/ios/ios_search_results_signed_in.png) | ![iOS authenticated detail](screenshots/ios/ios_photo_detail_authenticated.png) |

#### macOS

| Empty state | Search results | Photo detail |
|:-----------:|:--------------:|:------------:|
| ![macOS empty state](screenshots/macos/macos_empty_state.png) | ![macOS search results](screenshots/macos/macos_search_results.png) | ![macOS photo detail](screenshots/macos/macos_photo_detail.png) |

### Requirements

- macOS 12+ or iOS 16+
- Xcode 16+ (or Swift 5.9 CLI tools for the macOS version)
- A [Flickr API key](https://www.flickr.com/services/api/misc.api_keys.html)

### Running on macOS

```bash
# Option 1 — environment variable (no files left on disk)
FLICKR_API_KEY=your_api_key swift run FlickrDemoApp

# Option 2 — credential file
echo "your_api_key" > /tmp/flickr_api_key
swift run FlickrDemoApp
```

Run both commands from the package root (`AWFlickrServices/` directory).
The window appears automatically and the search field accepts keyboard input right away.

> **Note:** `swift run` does not give the process foreground focus by default on macOS.
> The demo calls `NSApp.activate(ignoringOtherApps: true)` in `.onAppear` so the
> search field responds to keyboard input immediately without needing to click first.

### Running on iOS Simulator

```bash
# 1. Generate the Xcode project (only needed once, or after editing project.yml)
cd Examples/FlickrDemoApp-iOS
xcodegen generate

# 2. Open in Xcode
open FlickrDemoApp-iOS.xcodeproj
```

In Xcode:
1. Select the **FlickrDemoApp-iOS** scheme and an iPhone simulator.
2. Open **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**
   and add `FLICKR_API_KEY` = `your_api_key`.
3. Press **⌘R** to build and run.

Alternatively, if you skip step 2, an **API Key** field appears at the top of the
app on first launch — paste your key there.

Layout adapts automatically: VStack on iPhone, HStack sidebar on iPad/macOS.
