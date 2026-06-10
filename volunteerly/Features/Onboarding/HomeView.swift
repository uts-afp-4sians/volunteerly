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
                .offset(y: -logoSize / 2)        // straddle the seam
                .padding(.bottom, -logoSize / 2) // reclaim layout space

            Image(.volunteerlyTitle)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 110)
                .padding(.top, -24)

            Text("\u{201C}Where purpose meets people\u{201D}")
                .font(.bodyStrong.italic())
                .foregroundStyle(Color.onBrand)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
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
                    router?.route = .auth
                } label: {
                    Text("Sign Up").frame(maxWidth: .infinity)
                }
                .buttonStyle(LandingSecondaryButtonStyle())
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

/// Continuously translates two stacked copies of `HomeBackground` downward to
/// produce a seamless, endless scroll. `TimelineView(.animation)` drives the
/// offset off the elapsed time since the view appeared, so the loop self-
/// corrects after backgrounding and pauses automatically when offscreen.
private struct ScrollingBackground: View {
    /// Scroll speed in points per second.
    var speed: CGFloat = 20
    /// Anchored when the view first materialises so the loop starts at the top
    /// of the image rather than at a random offset of wall-clock time.
    @State private var startDate = Date()

    var body: some View {
        GeometryReader { proxy in
            let imageAspect: CGFloat = 1536.0 / 2752.0  // width / height of HomeBackground.png
            // Each tile fills the viewport's width; height follows the native aspect.
            let tileHeight = proxy.size.width / imageAspect

            TimelineView(.animation) { context in
                let elapsed = CGFloat(context.date.timeIntervalSince(startDate))
                // Cycles 0 → tileHeight → 0, so the two stacked copies appear to
                // scroll forever without a visible seam.
                let offset = (elapsed * speed).truncatingRemainder(dividingBy: tileHeight)

                VStack(spacing: 0) {
                    Image(.homeBackground)
                        .resizable()
                        .frame(width: proxy.size.width, height: tileHeight)
                    Image(.homeBackground)
                        .resizable()
                        .frame(width: proxy.size.width, height: tileHeight)
                }
                // Start with the lower copy covering the viewport (offset == 0,
                // dy == -tileHeight, so its top edge sits at y=0). As offset grows
                // the pair slides downward, revealing the upper copy's bottom edge
                // from the top of the viewport.
                .offset(y: offset - tileHeight)
            }
        }
        .clipped()
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
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
}
