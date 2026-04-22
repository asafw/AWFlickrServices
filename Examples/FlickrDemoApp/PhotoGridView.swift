// PhotoGridView.swift — Scrollable grid of photo thumbnails.

import SwiftUI
import AWFlickrServices

struct PhotoGridView: View {

    let photos: [FlickrPhoto]
    @ObservedObject var viewModel: DemoViewModel

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(photos, id: \.id) { photo in
                    NavigationLink {
                        PhotoDetailView(photo: photo, viewModel: viewModel)
                    } label: {
                        ThumbnailView(urlString: photo.thumbnailPhotoURLString())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

// MARK: - Thumbnail cell

private struct ThumbnailView: View {

    let urlString: String
    @State private var imageData: Data? = nil

    // FlickrPhotosProtocol conformance via extension on any type — we use a
    // lightweight struct here to demonstrate the mixin pattern directly.
    private struct Loader: FlickrPhotosProtocol { }
    private let loader = Loader()

    var body: some View {
        Group {
            if let data = imageData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .foregroundStyle(.quaternary)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: urlString) {
            guard let url = URL(string: urlString) else { return }
            if let data = try? await loader.downloadImageData(from: url) {
                imageData = data
            }
        }
    }
}
