import SwiftUI

/// Loading placeholder for `ProgramCard` — a full-bleed grey card with the same
/// 263pt height and 16pt corner, carrying bottom content bars (category chip,
/// title, description, progress, metrics) so the list keeps its shape and rhythm
/// while programs load. Swept by `.shimmering()`; static/dimmed under Reduce
/// Motion. Mirrors `ProgramCard`'s bottom-leading content cluster.
struct ProgramCardSkeleton: View {
    private var base: Color { Color(.systemGray5) }
    private var bar: Color { Color(.systemGray4) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            base

            VStack(alignment: .leading, spacing: 6) {
                Circle()
                    .fill(bar)
                    .frame(width: 24, height: 24)        // category chip
                skeletonBar(width: 170, height: 16)      // title
                skeletonBar(width: 120, height: 12)      // description
                Capsule()
                    .fill(bar)
                    .frame(height: 6)                    // progress bar
                    .padding(.top, 2)
                HStack(spacing: 12) {                     // metrics
                    skeletonBar(width: 48, height: 12)
                    skeletonBar(width: 48, height: 12)
                }
                .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 263)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shimmering()
        .accessibilityHidden(true)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(bar)
            .frame(width: width, height: height)
    }
}

#Preview {
    ProgramCardSkeleton()
        .padding()
}
