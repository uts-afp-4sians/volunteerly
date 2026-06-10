import SwiftUI

/// Continuously rotating arc whose stroke fades from solid (head) to
/// transparent (tail) — the classic "tail-fade" loader. Takes a `color`
/// parameter rather than the system tint so it can stay on-brand.
/// Reused by `SplashView` and `WelcomeView`.
struct FadingTailSpinner: View {
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
