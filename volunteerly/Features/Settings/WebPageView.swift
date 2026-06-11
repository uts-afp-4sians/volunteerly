import SwiftUI

/// Hosts a remote page (e.g. the privacy policy) inside the app rather than
/// kicking out to Safari. Shows a spinner while loading and a retry affordance
/// if the page can't be reached.
struct WebPageView: View {
    let title: String
    let url: URL

    @State private var isLoading = true
    @State private var didFail = false
    /// Bumped to force a fresh `WebView` (and reload) on retry.
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if didFail {
                failure
            } else {
                WebView(url: url, isLoading: $isLoading, didFail: $didFail)
                    .id(reloadToken)
                    .opacity(isLoading ? 0 : 1)
            }

            if isLoading && !didFail {
                ProgressView()
                    .tint(Theme.forest)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    private var failure: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(Theme.textSecondary)
            Text("Couldn't load the page")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                isLoading = true
                didFail = false
                reloadToken += 1
            } label: {
                Text("Retry")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 48)
                    .background(Theme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding(32)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    NavigationStack {
        WebPageView(
            title: "Privacy policy",
            url: URL(string: "https://example.com")!
        )
    }
}
