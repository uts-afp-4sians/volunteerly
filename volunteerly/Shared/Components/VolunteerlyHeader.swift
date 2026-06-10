import SwiftUI

/// The app logo + "Volunteerly" wordmark shown atop the main menus.
/// Tapping the wordmark returns the user to the home page (the Programs tab
/// at its root); the trailing gear opens Settings on the current tab.
struct VolunteerlyHeader: View {
    // Optional so previews that don't inject a router still render (and no-op on tap).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?

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

            // Pushes SettingsView onto the current tab's NavigationStack via the
            // router-owned path (`TabRouter.showSettings`), so the gear always
            // lands on Settings regardless of which tab the user is on.
            Button {
                tabRouter?.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
