import SwiftUI

/// Program list/grid card (Figma node 776:977). A full-bleed banner with a
/// bottom gradient scrim, over which sit the category emoji, title, a truncated
/// description, a participants progress bar, the participants/distance metrics,
/// and a commitment-frequency chip.
struct ProgramCard: View {
    let program: Program
    /// When set, overrides the model's `distanceKm` (used by the "Similar
    /// program nearby" card, which carries its own computed distance).
    var distanceKm: Double? = nil
    /// Category glyph for the corner chip, resolved by the caller from its
    /// loaded categories (`categoryId` → name → emoji). Hidden when nil.
    var categoryEmoji: String? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // The image lives in an overlay of a layout-neutral base so its
            // `.fill` aspect ratio can't widen the card past the proposed
            // width (same pattern as the detail banner).
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 253)
                .overlay(
                    CachedAsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                )
                .clipped()

            // Transparent at the top, deepening to ~70% black by the lower
            // third so the white content stays legible (Figma gradient).
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.7), location: 0.64),
                    .init(color: .black.opacity(0.7), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: 263)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let categoryEmoji {
                emojiChip(categoryEmoji)
            }

            Text(program.name)
                .font(.cardTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(program.description)
                .font(.captionText)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)

            progressBar
                .padding(.top, 2)

            metricsRow
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func emojiChip(_ emoji: String) -> some View {
        Text(emoji)
            .font(.captionText)
            .frame(width: 24, height: 24)
            .background(.white.opacity(0.3), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
    }

    /// Joined-vs-capacity bar — `participantCount / maxVolunteers`.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black50)
                Capsule()
                    .fill(Color.brand300)
                    .frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 6)
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metric(systemImage: "person.2.fill", text: "\(participantCount)/\(program.maxVolunteers)")
            if let distance = resolvedDistanceKm {
                metric(systemImage: "map.fill", text: Self.distanceText(distance))
            }

            Spacer(minLength: 8)

            if let frequency = program.commitmentFrequency {
                frequencyChip(frequency.label)
            }
        }
    }

    private func metric(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.captionText)
        .foregroundStyle(.white.opacity(0.9))
    }

    private func frequencyChip(_ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
            Text(label)
        }
        .font(.captionText)
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Derived values

    private var participantCount: Int { program.participantCount ?? 0 }

    private var resolvedDistanceKm: Double? { distanceKm ?? program.distanceKm }

    private var progressFraction: Double {
        guard program.maxVolunteers > 0 else { return 0 }
        return min(1, max(0, Double(participantCount) / Double(program.maxVolunteers)))
    }

    // Pure formatter — marked `nonisolated` so it can be passed as a plain
    // function value without a main-actor isolation warning.
    nonisolated private static func distanceText(_ km: Double) -> String {
        km < 10 ? String(format: "%.1fkm", km) : String(format: "%.0fkm", km)
    }
}

#Preview {
    ProgramCard(program: MockData.programs[0], categoryEmoji: "🌱")
        .padding()
}
