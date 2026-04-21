# AWFlickrServices

![CI](https://github.com/asafw/AWFlickrServices/actions/workflows/ios.yml/badge.svg)

A dependency-free Swift Package for integrating the Flickr API in iOS and macOS applications.
Uses a **protocol mixin pattern** — conform any Swift type to `FlickrOAuthProtocol`
or `FlickrPhotosProtocol` and get full API access through protocol extension default
implementations. No subclassing or dependency injection required.

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
