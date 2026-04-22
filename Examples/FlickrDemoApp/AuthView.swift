// AuthView.swift — OAuth sign-in / sign-out section shown above the search bar.

import SwiftUI

struct AuthView: View {

    @ObservedObject var viewModel: DemoViewModel

    var body: some View {
        if viewModel.isAuthenticated {
            HStack {
                Label(viewModel.signedInAs ?? "Signed in", systemImage: "person.fill.checkmark")
                    .foregroundStyle(.green)
                Spacer()
                Button("Sign out") { viewModel.signOut() }
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Secret")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    SecureField("Required for fave / comment", text: $viewModel.apiSecret)
                        .textFieldStyle(.roundedBorder)
                        #if os(macOS)
                        // Suppress macOS Passwords/AutoFill helper — this is an API secret, not a login password.
                        .textContentType(nil as NSTextContentType?)
                        #endif
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Sign in with Flickr") { viewModel.signIn() }
                        .disabled(viewModel.apiKey.isEmpty || viewModel.apiSecret.isEmpty || viewModel.isSigningIn)

                    if viewModel.isSigningIn {
                        ProgressView()
                    } else if let err = viewModel.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 6)
        }
    }
}
