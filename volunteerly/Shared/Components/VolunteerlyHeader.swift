import SwiftUI

/// The app logo + "Volunteerly" wordmark shown atop the main menus.
/// Tapping it returns the user to the home page (the Programs tab at its root).
struct VolunteerlyHeader: View {
    // Optional so previews that don't inject a router still render (and no-op on tap).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?

    var body: some View {
        Button {
            tabRouter?.goHome()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "hands.and.sparkles.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                    )
                Text("Volunteerly")
                    .font(.bodyText)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Volunteerly, go to home")
        .accessibilityAddTraits(.isButton)
    }
}
