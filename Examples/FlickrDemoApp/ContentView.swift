// ContentView.swift — Root view: search bar + photo grid.

import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = DemoViewModel()

    var body: some View {
        // NavigationStack (macOS 13+/iOS 16+) enables NavigationLink in PhotoGridView.
        // Fall back to NavigationView on macOS 12.
        if #available(macOS 13.0, *) {
            NavigationStack { navigationContent }
        } else {
            NavigationView { navigationContent }
        }
    }

    private var navigationContent: some View {
        VStack(spacing: 0) {
            apiKeyRow
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
                .onSubmit { viewModel.search() }

            Button("Search") { viewModel.search() }
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
            PhotoGridView(photos: viewModel.photos, apiKey: viewModel.apiKey)
        }
    }
}
