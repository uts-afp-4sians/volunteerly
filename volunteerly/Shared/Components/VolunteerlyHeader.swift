import SwiftUI

/// The app logo + "Volunteerly" wordmark shown atop the main menus.
/// Tapping the wordmark returns the user to the home page (the Programs tab
/// at its root). Tapping the trailing avatar pushes the profile settings.
struct VolunteerlyHeader: View {
    // Optional so previews that don't inject a router still render (and no-op on tap).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?
    // Optional so previews that don't inject the store still render the placeholder.
    @Environment(UserProfileStore.self) private var profileStore: UserProfileStore?

    var body: some View {
        // Read the @Observable properties directly inside body so SwiftUI's
        // observation tracking definitely picks them up even with the
        // optional @Environment lookup form used here.
        let imageData = profileStore?.profileImageData
        let imageURL = profileStore?.profileImageURL

        return HStack {
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
                Avatar(source: avatarSource(data: imageData, urlString: imageURL), size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My profile")
        }
    }

    /// Pick whichever image source the store has: a freshly picked Photo
    /// (`profileImageData`), the saved CDN URL, or the silhouette fallback.
    private func avatarSource(data: Data?, urlString: String?) -> Avatar.Source {
        if let data, let uiImage = UIImage(data: data) {
            return .image(Image(uiImage: uiImage))
        }
        if let urlString, let url = URL(string: urlString) {
            return .remote(url)
        }
        return .placeholder
    }
}
