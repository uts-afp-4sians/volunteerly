import SwiftUI

/// Landing screen shown before authentication. The full screen carries an
/// endlessly scrolling illustration; a rounded-top green panel sits at the
/// bottom with the title, tagline, and Log In / Sign Up CTAs. The earth-in-
/// hand logo straddles the seam between them.
struct HomeView: View {
    @Environment(AppRouter.self) private var router: AppRouter?

    private let logoSize: CGFloat = 280
    private let greenPanelHeight: CGFloat = 460
    private let panelCornerRadius: CGFloat = 40

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollingBackground()

            greenPanel
        }
        .ignoresSafeArea()
    }

    private var greenPanel: some View {
        VStack(spacing: 0) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .offset(y: -logoSize / 2)     
                .padding(.bottom, -logoSize / 2)

            Image(.volunteerlyTitle)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 110)
                .padding(.top, -48)

            Text("\u{201C}Where purpose meets people\u{201D}")
                .font(.bodyStrong.italic())
                .foregroundStyle(Color.onBrand)
                .multilineTextAlignment(.center)
                .padding(.top, -4)
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            VStack(spacing: 14) {
                Button {
                    router?.route = .auth
                } label: {
                    Text("Log in").frame(maxWidth: .infinity)
                }
                .buttonStyle(LandingPrimaryButtonStyle())

                Button {
                    router?.pendingAuthRoute = .signup
                    router?.route = .auth
                } label: {
                    Text("Sign Up").frame(maxWidth: .infinity)
                }
                .buttonStyle(LandingSecondaryButtonStyle())

                Button {
                    router?.pendingAuthRoute = .resetPassword
                    router?.route = .auth
                } label: {
                    Text("Forgot password?")
                        .font(.bodyText)
                        .underline()
                        .foregroundStyle(Color.onBrand)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity)
        .frame(height: greenPanelHeight)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: panelCornerRadius,
                topTrailingRadius: panelCornerRadius,
                style: .continuous
            )
            .fill(Theme.forest)
        )
    }
}

/// Pale-yellow primary CTA used inside the brand-green panel.
private struct LandingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(Theme.textPrimary)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentYellow : Color.accentYellowLight)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined secondary CTA — pale-yellow border, cream label — pairs with the
/// primary on the brand-green panel.
private struct LandingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(Color.onBrand)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.accentYellowLight, lineWidth: 1.5)
            )
            // Make the full rounded rectangle hit-testable, not just the
            // stroked border + label glyphs.
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
}
