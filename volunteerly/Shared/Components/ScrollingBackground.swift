import SwiftUI

/// Continuously translates two stacked copies of `HomeBackground` downward to
/// produce a seamless, endless scroll. Reused by `HomeView` (landing) and
/// `WelcomeView` (post-signup). `TimelineView(.animation)` drives the offset
/// off the elapsed time since the view appeared, so the loop self-corrects
/// after backgrounding and pauses automatically when offscreen.
struct ScrollingBackground: View {
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
                // Cycles 0 → tileHeight → 0 so the two stacked copies appear
                // to scroll forever without a visible seam.
                let offset = (elapsed * speed).truncatingRemainder(dividingBy: tileHeight)

                VStack(spacing: 0) {
                    Image(.homeBackground)
                        .resizable()
                        .frame(width: proxy.size.width, height: tileHeight)
                    Image(.homeBackground)
                        .resizable()
                        .frame(width: proxy.size.width, height: tileHeight)
                }
                .offset(y: offset - tileHeight)
            }
        }
        .clipped()
    }
}
