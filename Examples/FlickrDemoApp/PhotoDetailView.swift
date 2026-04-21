// PhotoDetailView.swift — Large photo + metadata fetched via getInfo and getComments.

import SwiftUI
import AWFlickrServices

struct PhotoDetailView: View {

    let photo: FlickrPhoto
    let apiKey: String

    @State private var imageData: Data? = nil
    @State private var info: FlickrInfoResponse? = nil
    @State private var comments: [String] = []
    @State private var isLoadingInfo = true

    /// nil on macOS — treated as non-compact, giving the HStack layout.
    @Environment(\.horizontalSizeClass) private var sizeClass

    private struct Service: FlickrPhotosProtocol { }
    private let service = Service()

    var body: some View {
        ScrollView {
            Group {
                if sizeClass == .compact {
                    // iPhone portrait — stack photo above metadata
                    VStack(alignment: .leading, spacing: 16) {
                        photoArea.frame(maxHeight: 300)
                        metadataArea
                    }
                } else {
                    // macOS / iPad — photo left, metadata sidebar right
                    HStack(alignment: .top, spacing: 16) {
                        photoArea.frame(maxWidth: 500, maxHeight: 500)
                        metadataArea.frame(width: 220)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(photo.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadAll() }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var photoArea: some View {
        Group {
            if let data = imageData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .foregroundStyle(.quaternary)
                    .overlay { ProgressView() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var metadataArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(photo.title)
                .font(.title2)
                .bold()

            if isLoadingInfo {
                ProgressView("Loading info…")
            } else {
                if let info {
                    InfoRow(label: "By", value: info.photo.owner.realname)
                    InfoRow(label: "Taken", value: info.photo.dates.taken)
                    InfoRow(label: "Views", value: info.photo.views)
                    if let location = info.photo.owner.location, !location.isEmpty {
                        InfoRow(label: "Location", value: location)
                    }
                }

                if !comments.isEmpty {
                    Divider()
                    Text("Comments").font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(comments.indices, id: \.self) { i in
                            Text(comments[i])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info row

    private struct InfoRow: View {
        let label: String
        let value: String
        var body: some View {
            HStack(alignment: .top) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Text(value)
            }
            .font(.caption)
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        if let url = URL(string: photo.largePhotoURLString()) {
            service.downloadImageData(from: url) { result in
                if case .success(let data) = result {
                    DispatchQueue.main.async { imageData = data }
                }
            }
        }

        let infoRequest = FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        service.getInfo(apiKey: apiKey, infoRequest: infoRequest) { result in
            DispatchQueue.main.async {
                isLoadingInfo = false
                if case .success(let fetched) = result { info = fetched }
            }
        }

        let commentsRequest = FlickrCommentsRequest(photo_id: photo.id)
        service.getComments(apiKey: apiKey, commentsRequest: commentsRequest) { result in
            if case .success(let fetched) = result {
                DispatchQueue.main.async { comments = fetched }
            }
        }
    }
}
