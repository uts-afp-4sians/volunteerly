import SwiftUI

struct ProgramCard: View {
    let program: Program

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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            AvatarStack(initials: avatarInitials)
                .padding(10)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack(alignment: .bottom, spacing: 8) {
                Text(program.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    metric(systemImage: "person.2.fill", text: "\(program.maxVolunteers)")
                    metric(systemImage: "map.fill", text: startDateText)
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 89, alignment: .leading)
        .background(.regularMaterial)
    }

    private func metric(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var startDateText: String {
        program.startDatetime.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Derive up to two avatar initials from the program name (placeholder for
    /// real participant data).
    private var avatarInitials: [String] {
        program.name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
    }
}

/// Overlapping circular avatar badges shown on a program card.
struct AvatarStack: View {
    let initials: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(initials.enumerated()), id: \.offset) { _, letter in
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(letter)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            }
        }
    }
}

#Preview {
    ProgramCard(program: MockData.programs[0])
        .padding()
}
