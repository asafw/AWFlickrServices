// PhotoDetailView.swift — Large photo + metadata fetched via getInfo and getComments.
// Also demonstrates fave, unfave, and comment when the user is signed in via OAuth.

import SwiftUI
import AWFlickrServices

struct PhotoDetailView: View {

    let photo: FlickrPhoto
    @ObservedObject var viewModel: DemoViewModel

    @State private var imageData: Data? = nil
    @State private var info: FlickrInfoResponse? = nil
    @State private var comments: [String] = []
    @State private var isLoadingInfo = true

    // Fave / unfave
    @State private var isFaved: Bool = false
    @State private var isFaving: Bool = false

    // Comment
    @State private var newComment: String = ""
    @State private var isPostingComment: Bool = false

    // Action error (fave/unfave/comment failures)
    @State private var actionError: String? = nil

    /// nil on macOS — treated as non-compact, giving the HStack layout.
    @Environment(\.horizontalSizeClass) private var sizeClass

    private struct Service: FlickrPhotosProtocol { }
    private let service = Service()

    var body: some View {
        ScrollView {
            Group {
                if sizeClass == .compact {
                    VStack(alignment: .leading, spacing: 16) {
                        photoArea.frame(maxHeight: 300)
                        metadataArea
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        photoArea.frame(maxWidth: 500, maxHeight: 500)
                        metadataArea.frame(width: 260)
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

            // Fave / unfave + comment — only available when signed in via OAuth
            if viewModel.isAuthenticated {
                Divider()

                // Fave / unfave
                HStack(spacing: 12) {
                    Button {
                        toggleFave()
                    } label: {
                        Label(
                            isFaved ? "Unfave" : "Fave",
                            systemImage: isFaved ? "heart.fill" : "heart"
                        )
                    }
                    .disabled(isFaving)
                    .foregroundStyle(isFaved ? .pink : .primary)

                    if isFaving { ProgressView() }
                }

                // Post a comment
                HStack {
                    TextField("Add a comment…", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .submitLabel(.send)
                        #endif
                        .onSubmit { postComment() }

                    Button("Post") { postComment() }
                        .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || isPostingComment)
                }

                if isPostingComment {
                    ProgressView("Posting…")
                }

                if let actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(.red)
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
        #if DEBUG
        if let mockInfo = viewModel.mockPhotoInfo {
            isLoadingInfo = false
            info = mockInfo
            comments = viewModel.mockPhotoComments
            return
        }
        #endif

        if let url = URL(string: photo.largePhotoURLString()) {
            service.downloadImageData(from: url) { result in
                if case .success(let data) = result {
                    DispatchQueue.main.async { imageData = data }
                }
            }
        }

        let infoRequest = FlickrInfoRequest(photo_id: photo.id, secret: photo.secret)
        service.getInfo(apiKey: viewModel.apiKey, infoRequest: infoRequest) { result in
            DispatchQueue.main.async {
                isLoadingInfo = false
                if case .success(let fetched) = result { info = fetched }
            }
        }

        let commentsRequest = FlickrCommentsRequest(photo_id: photo.id)
        service.getComments(apiKey: viewModel.apiKey, commentsRequest: commentsRequest) { result in
            if case .success(let fetched) = result {
                DispatchQueue.main.async { comments = fetched }
            }
        }
    }

    // MARK: - Fave / unfave

    private func toggleFave() {
        isFaving = true
        actionError = nil
        let request = FlickrFaveRequest(photo_id: photo.id)
        if isFaved {
            service.unfave(
                apiKey: viewModel.apiKey,
                apiSecret: viewModel.apiSecret,
                oauthToken: viewModel.oauthToken,
                oauthTokenSecret: viewModel.oauthTokenSecret,
                faveRequest: request
            ) { result in
                DispatchQueue.main.async {
                    isFaving = false
                    switch result {
                    case .success: isFaved = false
                    case .failure(let error): actionError = error.localizedDescription
                    }
                }
            }
        } else {
            service.fave(
                apiKey: viewModel.apiKey,
                apiSecret: viewModel.apiSecret,
                oauthToken: viewModel.oauthToken,
                oauthTokenSecret: viewModel.oauthTokenSecret,
                faveRequest: request
            ) { result in
                DispatchQueue.main.async {
                    isFaving = false
                    switch result {
                    case .success: isFaved = true
                    case .failure(let error): actionError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Comment

    private func postComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isPostingComment = true
        actionError = nil
        let request = FlickrCommentRequest(photo_id: photo.id, comment_text: text)
        service.comment(
            apiKey: viewModel.apiKey,
            apiSecret: viewModel.apiSecret,
            oauthToken: viewModel.oauthToken,
            oauthTokenSecret: viewModel.oauthTokenSecret,
            commentRequest: request
        ) { result in
            DispatchQueue.main.async {
                isPostingComment = false
                switch result {
                case .success:
                    comments.append(text)
                    newComment = ""
                case .failure(let error):
                    actionError = error.localizedDescription
                }
            }
        }
    }
}

