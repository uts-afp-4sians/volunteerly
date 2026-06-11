import SwiftUI

/// Confirmation screen shown after a user joins a program ("You're in!").
/// Mirrors Figma node 134:335 using the joined program and live participant
/// profiles returned by the API.
struct ProgramJoinedView: View {
    let program: Program
    let teamName: String?
    let members: [UserProfile]
    let participantCount: Int

    var onCheckTeamBoard: () -> Void = {}
    var onFindOtherOpportunities: () -> Void = {}

    private let visibleAvatars = 4
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    banner
                        .padding(.top, 24)

                    heading
                        .padding(.top, 58)

                    bodyText
                        .padding(.top, 16)

                    teammates
                        .padding(.top, 44)

                    Spacer(minLength: 64)

                    actions
                        .padding(.bottom, 46)
                }
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, horizontalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    // MARK: - Banner

    private var banner: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 215)
            .overlay(
                CachedAsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Heading

    private var heading: some View {
        Text("You're in!")
            .largeTitleStyle()
    }

    private var bodyText: some View {
        Text(
            "You've teamed up with **\(teamName ?? "your community")** working towards **\(program.name)**"
        )
            .font(.bodyText)
            .foregroundStyle(Theme.textBody)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 290)
    }

    // MARK: - Teammates

    @ViewBuilder
    private var teammates: some View {
        VStack(spacing: 20) {
            HStack(spacing: 21) {
                ForEach(0..<displayedAvatarCount, id: \.self) { index in
                    Avatar(url: avatarURL(at: index), size: 52)
                }
            }

            let remaining = max(0, participantCount - displayedAvatarCount)
            if remaining > 0 {
                Text("And \(remaining) more!")
                    .font(.subheadText)
                    .foregroundStyle(Theme.textBody)
            }
        }
    }

    private var displayedAvatarCount: Int {
        min(visibleAvatars, max(participantCount, 0))
    }

    private func avatarURL(at index: Int) -> URL? {
        guard members.indices.contains(index),
              let rawURL = members[index].profileImageURL,
              !rawURL.isEmpty else {
            return nil
        }
        return URL(string: rawURL)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 16) {
            Button(action: onCheckTeamBoard) {
                HStack(spacing: 8) {
                    Text("Check the team board")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button(action: onFindOtherOpportunities) {
                Text("or find other opportunities")
                    .font(.bodyText)
                    .underline()
                    .foregroundStyle(Theme.brand300)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return ProgramJoinedView(
        program: MockData.programs[0],
        teamName: "Community Garden",
        members: MockData.memberProfiles,
        participantCount: 7
    )
}
