// ContentView.swift — Root view: search bar + photo grid.

import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = DemoViewModel()

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            resultArea
        }
        .navigationTitle("Flickr Demo")
    }

    // MARK: - Sub-views

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
