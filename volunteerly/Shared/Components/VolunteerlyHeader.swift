import SwiftUI

/// The app logo + "Volunteerly" wordmark shown atop the main menus.
/// Tapping the wordmark returns the user to the home page (the Programs tab
/// at its root). Tapping the trailing avatar pushes the profile settings.
struct VolunteerlyHeader: View {
    // Optional so previews that don't inject a router still render (and no-op on tap).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?

    var body: some View {
        HStack {
            Button {
                tabRouter?.goHome()
            } label: {
                HStack(spacing: 10) {
                    Image(.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("Volunteerly")
                        .font(.bodyText)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volunteerly, go to home")
            .accessibilityAddTraits(.isButton)

            Spacer()

            NavigationLink {
                ProfileSettingsView()
            } label: {
                Avatar(source: .placeholder, size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile settings")
        }
    }
}
