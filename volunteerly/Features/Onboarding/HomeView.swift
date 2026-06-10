import SwiftUI

/// Landing screen shown before authentication. White top half carries the logo
/// and yellow wordmark; brand-green bottom half carries the tagline and the
/// Log In / Sign Up calls to action.
struct HomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            topSection
            bottomSection
        }
        .ignoresSafeArea()
    }

    private var topSection: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 240)
            Image(.volunteerlyTitle)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 80)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var bottomSection: some View {
        VStack(spacing: 24) {
            Text("Where purpose meets people")
                .font(.bodyStrong)
                .foregroundStyle(Color.onBrand)
                .padding(.top, 32)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                NavigationLink(value: AuthRoute.login) {
                    Text("Log In").frame(maxWidth: .infinity)
                }
                .buttonStyle(LandingPrimaryButtonStyle())

                NavigationLink(value: AuthRoute.signup) {
                    Text("Sign Up").frame(maxWidth: .infinity)
                }
                .buttonStyle(LandingSecondaryButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .background(Theme.forest)
    }
}

/// Yellow-filled primary CTA used on the brand-green landing surface so it
/// stays visible against the green; mirrors `PrimaryActionButton`'s 30pt
/// corner radius and 15pt padding.
private struct LandingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(Theme.textPrimary)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentYellowDark : Color.accentYellow)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined secondary CTA on the brand-green landing surface.
private struct LandingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(Color.onBrand)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.onBrand, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
