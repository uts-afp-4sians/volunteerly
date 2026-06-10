import SwiftUI

struct SplashView: View {
    // Optional: an animated route switch can re-evaluate this view as it leaves
    // the hierarchy, outside the `.environment(router)` scope; a non-optional
    // lookup would `fatalError` there. See WelcomeView for the same rationale.
    @Environment(AppRouter.self) var router: AppRouter?

    var body: some View {
        VStack(spacing: 24) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            FadingTailSpinner(color: Theme.forest, size: 44, lineWidth: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .task {
            try? await Task.sleep(for: .seconds(2))
            router?.route = SessionManager.shared.hasSession ? .main : .home
        }
    }
}

/// Continuously rotating arc whose stroke fades from solid (head) to
/// transparent (tail) — the classic "tail-fade" loader, kept on-brand by
/// taking a `color` rather than the system tint.
private struct FadingTailSpinner: View {
    var color: Color
    var size: CGFloat
    var lineWidth: CGFloat
    /// Trim fraction — how much of the circle the arc covers. 0.8 = 288°.
    private let arcFraction: CGFloat = 0.8
    /// Seconds per full rotation.
    private let period: Double = 1.0
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let rotation = Angle.degrees(elapsed / period * 360)

            Circle()
                .trim(from: 0, to: arcFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0), color]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * arcFraction)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(rotation)
        }
    }
}

#Preview { SplashView().environment(AppRouter()) }
