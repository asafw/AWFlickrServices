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

    private struct Service: FlickrPhotosProtocol { }
    private let service = Service()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Large photo
            Group {
                if let data = imageData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .foregroundStyle(.quaternary)
                        .overlay { ProgressView() }
                }
            }
            .frame(maxWidth: 500, maxHeight: 500)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Metadata sidebar
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
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(comments.indices, id: \.self) { i in
                                    Text(comments[i])
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                Spacer()
            }
            .frame(width: 220)
            .padding(.top, 4)
        }
        .padding()
        .navigationTitle(photo.title)
        .task { await loadAll() }
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

    private func loadAll() async {
        // Large photo
        if let url = URL(string: photo.largePhotoURLString()) {
            service.downloadImageData(from: url) { result in
                if case .success(let data) = result {
                    DispatchQueue.main.async { imageData = data }
                }
            }
        }

        // Info + comments (concurrent, both fire-and-forget)
        let infoRequest = FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        service.getInfo(apiKey: apiKey, infoRequest: infoRequest) { result in
            if case .success(let fetched) = result {
                DispatchQueue.main.async { info = fetched }
            }
        }

        let commentsRequest = FlickrCommentsRequest(photo_id: photo.id)
        service.getComments(apiKey: apiKey, commentsRequest: commentsRequest) { result in
            if case .success(let fetched) = result {
                DispatchQueue.main.async { comments = fetched }
            }
        }

        DispatchQueue.main.async { isLoadingInfo = false }
    }
}
