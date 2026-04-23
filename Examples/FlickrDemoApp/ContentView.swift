// ContentView.swift — Root view: search bar + photo grid.

import SwiftUI

struct ContentView: View {

    @State private var viewModel = DemoViewModel()

    var body: some View {
        NavigationStack { navigationContent }
        // MOCK_DETAIL seam: presents the first photo's detail view as a sheet
        // so script-driven macOS screenshots can capture it without accessibility.
        .sheet(isPresented: $viewModel.showScreenshotDetail) {
            if let photo = viewModel.photos.first {
                PhotoDetailView(photo: photo, viewModel: viewModel)
            }
        }
    }

    private var navigationContent: some View {
        VStack(spacing: 0) {
            apiKeyRow
            Divider()
            AuthView(viewModel: viewModel)
            Divider()
            searchBar
            Divider()
            resultArea
        }
        .navigationTitle("Flickr Demo")
    }

    // MARK: - Sub-views

    /// Shown only when no API key is present — lets the user paste one directly
    /// in the UI instead of needing to restart with an env var set.
    @ViewBuilder
    private var apiKeyRow: some View {
        if viewModel.apiKey.isEmpty {
            HStack {
                Text("API Key")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                TextField("Paste your Flickr API key…", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search Flickr…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("search_field")
                .onSubmit { viewModel.search() }
                #if os(macOS)
                // Suppress macOS Passwords/AutoFill helper — the app isn't a sign-in form.
                .textContentType(nil as NSTextContentType?)
                #endif

            Button("Search") { viewModel.search() }
                .accessibilityIdentifier("search_button")
                .disabled(viewModel.searchText.isEmpty || viewModel.isLoading)
        }
        .padding()
    }

    @ViewBuilder
    private var resultArea: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .padding()
            Spacer()
        } else if viewModel.isLoading {
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.photos.isEmpty {
            Text(viewModel.searchText.isEmpty ? "Enter a search term above." : "No results.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PhotoGridView(photos: viewModel.photos, viewModel: viewModel)
        }
    }
}
