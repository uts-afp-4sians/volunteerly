import SwiftUI

/// Confirmation screen shown after a user joins a program ("You're in!").
/// Mirrors the Figma "C" frame: banner, celebratory heading, teammate avatars,
/// a "Your first session" summary card, and follow-up actions.
struct ProgramJoinedView: View {
    let program: Program
    /// The cause/category the program works towards, shown as the second bold span.
    let goal: String?
    /// Total teammates; drives the avatar row and the "And N more!" line.
    let teammateCount: Int

    var onCheckTeamBoard: () -> Void = {}
    var onFindOtherOpportunities: () -> Void = {}

    /// Avatars shown inline before the "And N more!" line.
    private let visibleAvatars = 4
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        ZStack {
            Color.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    banner
                        .padding(.top, 16)

                    VStack(spacing: 16) {
                        heading
                        bodyText
                    }
                    .padding(.top, 40)

                    teammates
                        .padding(.top, 32)

                    summaryCard
                        .padding(.top, 56)

                    actions
                        .padding(.top, 24)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Banner

    private var banner: some View {
        AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.systemGray5))
        }
        .frame(height: 215)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Heading

    private var heading: some View {
        Text("You're in!")
            .font(.pageTitle)
            .foregroundStyle(Theme.textPrimary)
    }

    private var bodyText: some View {
        Text("You've teamed up with **\(program.name)** working towards **\(goal ?? "your community")**")
            .font(.bodyText)
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Teammates

    @ViewBuilder
    private var teammates: some View {
        VStack(spacing: 16) {
            HStack(spacing: 21) {
                ForEach(0..<min(visibleAvatars, max(teammateCount, 0)), id: \.self) { _ in
                    Avatar(source: .placeholder, size: 55)
                }
            }

            let remaining = teammateCount - visibleAvatars
            if remaining > 0 {
                Text("And \(remaining) more!")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your first session")
                .font(Font.bodyStrong.italic())
                .foregroundStyle(Theme.textPrimary)
            Text(dateRange)
                .font(Font.bodyText.italic())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.textPrimary, lineWidth: 1)
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
            Button(action: onCheckTeamBoard) {
                HStack(spacing: 8) {
                    Text("Check the team board")
                    Image(systemName: "arrow.right")
                }
                .font(.bodyText)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 61)
                .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onFindOtherOpportunities) {
                Text("or find other opportunities")
                    .font(.bodyText)
                    .underline()
                    .foregroundStyle(Color.brand)
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
