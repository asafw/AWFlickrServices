# AWFlickrServices

![CI](https://github.com/asafw/AWFlickrServices/actions/workflows/ios.yml/badge.svg)

A dependency-free Swift Package for integrating the Flickr API in iOS applications.
Uses a **protocol mixin pattern** — conform your `UIViewController` to `FlickrOAuthProtocol`
or `FlickrPhotosProtocol` and get full API access through protocol extension default
implementations. No subclassing or dependency injection required.

## Version

* 2.0.0

## Prerequisites

* Xcode 16+
* Swift 5.9
* iOS 16+
* API Key and Secret obtained from Flickr

## Package capabilities

* OAuth 1.0a flow — Request Token, Authorization, Access Token
* Methods not requiring OAuth — `getPhotos`, `getImage`, `getInfo`, `getComments`
* Methods requiring OAuth — `fave`, `unfave`, `comment`

All public model types conform to `Sendable`.

## Migrating from v1

| v1 | v2 |
|---|---|
| `FlickrPhotosRequest(text:page:per_page:)` — `page`/`per_page` are `String` | `page`/`per_page` are `Int` |
| `Comment._content` | `Comment.content` |
| iOS 13+ | iOS 16+ |

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

Conform a `UIViewController` to both `FlickrOAuthProtocol` and
`ASWebAuthenticationPresentationContextProviding`, then implement the context provider:

```swift
import AWFlickrServices
import AuthenticationServices

class ViewController: UIViewController, FlickrOAuthProtocol, ASWebAuthenticationPresentationContextProviding {

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window ?? ASPresentationAnchor()
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

Conform a `UIViewController` to `FlickrPhotosProtocol`:

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

**Get image** (no OAuth required — uses built-in HTTP cache)

```swift
getImage(from: imageURL) { response in
    switch response {
    case .success(let image):
        // handle UIImage
    case .failure(let error):
        // handle error
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
