# AWFlickrServices 

Swift Package for integrating Flickr services in iOS applications.

## Prerequisites

Xcode 11.5  
Swift 5  
iOS 13  

## Packege methods

OAuth1 flow - Request Token, Authorization, Access Token  
Methods not requiring OAuth1 authentication - Get photos, Get image, Get info, Get comments  
Methods requiring OAuth1 authentication (oauthToken and oauthSecret) - Fave, Unfave, Comment  

## Usage

### FlickrOAuthProtocol

Implement OAuth1 flow in a UIViewController conforming to FlickrOAuthProtocol and ASWebAuthenticationPresentationContextProviding  
Implement ASWebAuthenticationPresentationContextProviding presentationAnchor method  

```swift
import AWFlickrServices
import AuthenticationServices

class ViewController: UIViewController, FlickrOAuthProtocol, ASWebAuthenticationPresentationContextProviding {
    // ViewController implementation

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window ?? ASPresentationAnchor()
        }
}
```
Call FlickrOAuthProtocol's performOAuthFlow method

```swift
    performOAuthFlow(from: self, completion: { response in
        switch response {
        case .success(let accessTokenReponse):
            //retain oauthTokenKey and oauthTokenSecretKey from accessTokenReponse
        case .failure(let error):
            //handle error
        }
    })
```

### FlickrPhotosProtocol

Use FlickrPhotosProtocol's methods in a UIViewController confrorming to FlickrPhotosProtocol

```swift
import AWFlickrServices

class ViewController: UIViewController, FlickrPhotosProtocol {
    // ViewController implementation
}
```

Get photos (not requiring OAuth1 authentication)

```swift 
    let photosRequest = PhotosRequest(text: searchText, page: page, per_page: per_page)
    getPhotos(photosRequest: photosRequest, completion: { response in
              switch response {
              case .success(let photos):   
                //handle photos
              case .failure(let error):
                  //handle error
              }
          })
```

Get image (not requiring OAuth1 authentication)  
This method is using the bulit-in http caching 

```swift
    getImage(from: imageURL, completion: { repsonse in
        switch repsonse {
        case .success(let image):
            //handle image
        case .failure(_):
            //handle error
        }
    })
```

Get info (not requiring OAuth1 authentication)
    
```swift
    let infoRequest = InfoRequest(photo_id: photoId, secret: photoSecret)
    getInfo(infoRequest: infoRequest, completion: { response in
               switch response {
               case .success(let infoResponse):
                  //handle infoResponse
               case .failure(let error):
                   //handle error
               }
           })
```

Get comments (not requiring OAuth1 authentication)

```swift
    let commentsRequest = CommentsRequest(photo_id: photoId)
    self.getComments(commentsRequest: commentsRequest, completion: { response in
        switch response {
        case .success(let comments):
            //handle comments
        case .failure(let error):
            //handle error
        }
    })
```
Fave (requires oauthToken and oauthSecret)

```swift
    let request = FaveRequest(photo_id: photoId)
    fave(faveRequest: request, completion: { response in
        switch response {
        case .success():
            //handle success
        case .failure(let error):
            //handle error
        }
    })
```

Unfave (requires oauthToken and oauthSecret)

```swift
    let request = FaveRequest(photo_id: photoId)
    unfave(faveRequest: request, completion: { response in
        switch response {
        case .success():
            //handle success
        case .failure(let error):
            //handle error
        }
    })
```

Comment (requires oauthToken and oauthSecret)

```swift
    let commentRequest = CommentRequest(photo_id: photoId, comment_text: commentText)
    comment(commentRequest: commentRequest, completion: { response in
            switch response {
            case .success():
                //handle success
            case .failure(let error):
                //handle error
        })
```

## Version 1.0.0
