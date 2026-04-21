// DemoViewModel.swift — Observable state connecting the UI to AWFlickrServices.

import Foundation
import Combine
import AWFlickrServices

/// Drives the demo UI. Conforms to FlickrPhotosProtocol and FlickrOAuthProtocol
/// so it can exercise the full public API surface of AWFlickrServices.
final class DemoViewModel: ObservableObject, FlickrPhotosProtocol, FlickrOAuthProtocol {

    // MARK: - Configuration

    /// Set via FLICKR_API_KEY env var, or paste into the in-app field.
    @Published var apiKey: String = ProcessInfo.processInfo.environment["FLICKR_API_KEY"] ?? ""
    /// Set via FLICKR_API_SECRET env var, or paste into the in-app field.
    @Published var apiSecret: String = ProcessInfo.processInfo.environment["FLICKR_API_SECRET"] ?? ""

    // MARK: - Auth state

    @Published var oauthToken: String = ""
    @Published var oauthTokenSecret: String = ""
    @Published var signedInAs: String? = nil
    @Published var isSigningIn: Bool = false
    @Published var authError: String? = nil

    var isAuthenticated: Bool { !oauthToken.isEmpty }

    private let presentationContext = PresentationContext()

    // MARK: - Search state

    @Published var searchText: String = ""
    @Published var photos: [FlickrPhoto] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Search

    func search() {
        guard !apiKey.isEmpty else {
            errorMessage = "Set your API key in the API Key field or via FLICKR_API_KEY env var."
            return
        }
        guard !searchText.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        photos = []
        getPhotos(
            apiKey: apiKey,
            photosRequest: FlickrPhotosRequest(text: searchText, page: 1, per_page: 20)
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let fetched):
                    self?.photos = fetched
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - OAuth

    func signIn() {
        guard !apiKey.isEmpty, !apiSecret.isEmpty else {
            authError = "API key and secret are both required to sign in."
            return
        }
        isSigningIn = true
        authError = nil
        performOAuthFlow(
            from: presentationContext,
            apiKey: apiKey,
            apiSecret: apiSecret,
            callbackUrlString: "flickrdemo://oauth"
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSigningIn = false
                switch result {
                case .success(let token):
                    self?.oauthToken = token.oauth_token
                    self?.oauthTokenSecret = token.oauth_token_secret
                    self?.signedInAs = token.fullname.isEmpty ? token.username : token.fullname
                case .failure(let error):
                    self?.authError = error.localizedDescription
                }
            }
        }
    }

    func signOut() {
        oauthToken = ""
        oauthTokenSecret = ""
        signedInAs = nil
    }
}
