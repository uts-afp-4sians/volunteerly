import SwiftUI

struct ProgramCard: View {
    let program: Program
    /// When set, the trailing metric shows this distance (km) instead of the
    /// start date — used by the "Similar program nearby" card.
    var distanceKm: Double?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity)
        .frame(height: 270)
        .background {
            AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name)
                .font(.bodyStrong)
                .foregroundStyle(Color.onBrand)
                .lineLimit(1)

            HStack(alignment: .bottom, spacing: 8) {
                Text(program.description)
                    .font(.labelItalic)
                    .foregroundStyle(Color.onBrand)
                    .lineLimit(2)

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    metric(systemImage: "person.2.fill", text: "\(program.maxVolunteers)")
                    metric(systemImage: "map.fill", text: distanceKm.map(Self.distanceText) ?? "-")
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 89, alignment: .leading)
        .background(Color.brand)
    }

    private func metric(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(Color.onBrand)
            Text(text)
                .font(.labelItalic)
                .foregroundStyle(Color.onBrand)
        }
    }

    // Pure formatter — marked `nonisolated` so it can be passed as a plain
    // function value to `Optional.map` without a main-actor isolation warning.
    nonisolated private static func distanceText(_ km: Double) -> String {
        km < 10 ? String(format: "%.1fkm", km) : String(format: "%.0fkm", km)
    }
}

#Preview {
    ProgramCard(program: MockData.programs[0])
        .padding()
}
