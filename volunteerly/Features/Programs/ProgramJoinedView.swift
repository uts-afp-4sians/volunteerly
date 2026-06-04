import SwiftUI

/// Confirmation screen shown after a user joins a program ("You're in!").
/// Mirrors the Figma "C" frame: banner, celebratory heading, teammate avatars,
/// a program summary card, and follow-up actions.
struct ProgramJoinedView: View {
    let program: Program
    /// The cause/category the program works towards, shown as "[Goal]".
    let goal: String?
    /// Total teammates; drives the avatar row and the "And N more!" line.
    let teammateCount: Int

    var onMeetTheTeam: () -> Void = {}
    var onFindOtherOpportunities: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    /// Avatars shown inline before the "And N more!" line.
    private let visibleAvatars = 4
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    banner
                    heading
                    avatarRow
                    moreLine
                    summaryCard
                    actions
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }

            closeButton
                .padding(.leading, horizontalPadding)
                .padding(.top, 8)
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("X")
                .font(.sectionHeader)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Banner

    private var banner: some View {
        AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.systemGray5))
        }
        .frame(height: 179)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(spacing: 16) {
            Text("You're in!")
                .font(.pageTitle)
                .foregroundStyle(.primary)
            Text("You've teamed up with **\(program.name)** working towards **\(goal ?? "your community")**")
                .font(.bodyText)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Teammates

    private var avatarRow: some View {
        HStack(spacing: 21) {
            ForEach(0..<min(visibleAvatars, max(teammateCount, 0)), id: \.self) { _ in
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 55, height: 55)
            }
        }
    }

    @ViewBuilder
    private var moreLine: some View {
        let remaining = teammateCount - visibleAvatars
        if remaining > 0 {
            Text("And \(remaining) more!")
                .font(.bodyText)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(program.name)
                .font(.bodyStrong)
                .foregroundStyle(.primary)
            Text(dateRange)
                .font(.bodyText)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary, lineWidth: 1)
        )
    }

    private var dateRange: String {
        let day = program.startDatetime.formatted(
            .dateTime.weekday(.wide).day().month(.abbreviated).year()
        )
        let start = program.startDatetime.formatted(date: .omitted, time: .shortened)
        let end = program.endDatetime.formatted(date: .omitted, time: .shortened)
        return "\(day)\n\(start) - \(end)"
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: onMeetTheTeam) {
                HStack(spacing: 8) {
                    Text("Meet the team")
                    Image(systemName: "arrow.right")
                }
                .font(.bodyText)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onFindOtherOpportunities) {
                Text("or find other opportunities")
                    .font(.bodyText)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return ProgramJoinedView(
        program: MockData.programs[0],
        goal: "Environment",
        teammateCount: 13
    )
}
