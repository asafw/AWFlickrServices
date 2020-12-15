# AWFlickrServices 

* Swift Package for integrating Flickr services in iOS applications.

## Version 

* 1.0.0

## Prerequisites

* Xcode 11.5  
* Swift 5  
* iOS 13
* API Key and Secret obtained from Flickr

## Package methods

* OAuth1 flow - Request Token, Authorization, Access Token  
* Methods not requiring OAuth1 authentication - Get photos, Get image, Get info, Get comments  
* Methods requiring OAuth1 authentication (oauthToken and oauthSecret) - Fave, Unfave, Comment  

## Usage

### Naming conventions for code examples

```swift
apiKey //API Key obtained from Flickr
apiSecret //API Secret obtained from Flickr
callbackUrlString //Callback to your app, used in OAuth authorization step
oauthToken //OAuth access token obtained in OAuth flow
oauthTokenSecret //OAuth access token secret obtained in OAuth flow
```

### FlickrOAuthProtocol

* Implement OAuth1 flow in a UIViewController conforming to FlickrOAuthProtocol and ASWebAuthenticationPresentationContextProviding  
* Implement ASWebAuthenticationPresentationContextProviding presentationAnchor method  

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
* Call FlickrOAuthProtocol's performOAuthFlow method

```swift
performOAuthFlow(from: self, 
                 apiKey: apiKey, 
                 apiSecret: apiSecret, 
                 callbackUrlString: callbackUrlString, 
                 completion: { response in
                    switch response {
                    case .success(let accessTokenReponse):
                        //retain oauth_token and oauth_token_secret from accessTokenReponse
                    case .failure(let error):
                        //handle error
                    }
})
```

### FlickrPhotosProtocol

* Use FlickrPhotosProtocol's methods in a UIViewController confrorming to FlickrPhotosProtocol

```swift
import AWFlickrServices

class ViewController: UIViewController, FlickrPhotosProtocol {
    // ViewController implementation
}
```

* Get photos (does not require OAuth1 authentication)

```swift 
let photosRequest = FlickrPhotosRequest(text: searchText, 
                                        page: page, 
                                        per_page: per_page)
getPhotos(apiKey: apiKey, 
          photosRequest: photosRequest, 
          completion: { response in
             switch response {
             case .success(let photos):   
                 //handle photos
             case .failure(let error):
                 //handle error
             }
})
```

* Get image (does not require OAuth1 authentication)  
* This method is using the bulit-in http caching 

```swift
getImage(from: imageURL, 
         completion: { repsonse in
            switch repsonse {
            case .success(let image):
                //handle image
            case .failure(_):
                //handle error
            }
})
```

* Get info (does not require OAuth1 authentication)
    
```swift
let infoRequest = FlickrInfoRequest(photo_id: photoId, 
                                    secret: photoSecret)
getInfo(apiKey: apiKey, 
        infoRequest: infoRequest, 
        completion: { response in
           switch response {
           case .success(let infoResponse):
               //handle infoResponse
           case .failure(let error):
               //handle error
           }
})
```

* Get comments (does not require OAuth1 authentication)

```swift
let commentsRequest = FlickrCommentsRequest(photo_id: photoId)
getComments(apiKey: apiKey, 
            commentsRequest: commentsRequest,
            completion: { response in
               switch response {
               case .success(let comments):
                   //handle comments
               case .failure(let error):
                   //handle error
               }
})
```
* Fave (requires oauthToken and oauthSecret)

```swift
let request = FlickrFaveRequest(photo_id: photoId)
fave(apiKey: apiKey, 
    apiSecret: apiSecret,
    oauthToken: oauthToken, 
    oauthTokenSecret: oauthTokenSecret,
    faveRequest: request, 
    completion: { response in
       switch response {
       case .success():
           //handle success
       case .failure(let error):
           //handle error
    }
})
```

* Unfave (requires oauthToken and oauthSecret)

```swift
let request = FlickrFaveRequest(photo_id: photoId)
unfave(apiKey: apiKey,
       apiSecret: apiSecret, 
       oauthToken: oauthToken, 
       oauthTokenSecret: oauthTokenSecret, 
       faveRequest: request, 
       completion: { response in
          switch response {
          case .success():
              //handle success
          case .failure(let error):
              //handle error
       }
})
```

* Comment (requires oauthToken and oauthSecret)

```swift
let commentRequest = FlickrCommentRequest(photo_id: photoId,
                                          comment_text: commentText)
comment(apiKey: apiKey, 
        apiSecret: apiSecret, 
        oauthToken: oauthToken,
        oauthTokenSecret: oauthTokenSecret,
        commentRequest: commentRequest, 
        completion: { response in
           switch response {
           case .success():
               //handle success
           case .failure(let error):
               //handle error
            }
})
```
