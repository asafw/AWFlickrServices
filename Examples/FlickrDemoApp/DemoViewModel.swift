// DemoViewModel.swift — Observable state connecting the UI to AWFlickrServices.

import Foundation
import Combine
import AWFlickrServices

/// Drives the demo UI. Conforms to both protocols so it can call all methods directly.
final class DemoViewModel: ObservableObject, FlickrPhotosProtocol {

    // MARK: - Configuration

    /// Paste your Flickr API key here, or set the FLICKR_API_KEY environment variable.
    @Published var apiKey: String = ProcessInfo.processInfo.environment["FLICKR_API_KEY"] ?? ""

    // MARK: - Search state

    @Published var searchText: String = ""
    @Published var photos: [FlickrPhoto] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Search

    func search() {
        guard !apiKey.isEmpty else {
            errorMessage = "Set your API key in DemoViewModel.apiKey or the FLICKR_API_KEY env var."
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
}
