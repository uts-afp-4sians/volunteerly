import SwiftUI

/// The app logo + "Volunteerly" wordmark shown atop the main menus.
/// Tapping the wordmark returns the user to the home page (the Programs tab
/// at its root); the trailing avatar opens My Page on the current tab.
struct VolunteerlyHeader: View {
    // Optional so previews that don't inject a router still render (and no-op on tap).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?
    // Optional so previews that don't inject the store still render the placeholder.
    @Environment(UserProfileStore.self) private var profileStore: UserProfileStore?

    var body: some View {
        HStack {
            Button {
                tabRouter?.goHome()
            } label: {
                HStack(spacing: 0) {
                    Image(.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Image(.volunteerlyTitle)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 130, maxHeight: 36)
                        .padding(.leading, -6)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volunteerly, go to home")
            .accessibilityAddTraits(.isButton)

            Spacer()

            // Pushes MyPageView onto the current tab's NavigationStack via the
            // `navigationDestination(for: ProfileRoute.self)` registered in
            // MainTabView, so the avatar always lands on the profile screen
            // regardless of which tab the user is on.
            NavigationLink(value: ProfileRoute()) {
                Avatar(source: headerAvatarSource, size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My profile")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pick whichever image source the store has: a freshly picked Photo
    /// (`profileImageData`), the saved CDN URL, or the silhouette fallback.
    private var headerAvatarSource: Avatar.Source {
        if let data = profileStore?.profileImageData, let uiImage = UIImage(data: data) {
            return .image(Image(uiImage: uiImage))
        }
        if let urlString = profileStore?.profileImageURL, let url = URL(string: urlString) {
            return .remote(url)
        }
        return .placeholder
    }
}
