import SwiftUI
import MapKit

struct ProgramDetailView: View {
    let programId: Int

    @State private var viewModel: ProgramDetailViewModel
    @State private var showJoinedConfirmation = false
    @State private var bannerSelection = 0
    @Environment(\.dismiss) private var dismiss

    private let httpClient: HTTPClient
    private let horizontalPadding: CGFloat = 20

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.programId = programId
        self.httpClient = httpClient
        _viewModel = State(
            initialValue: ProgramDetailViewModel(programId: programId, httpClient: httpClient)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    banner

                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)

            topControls
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let program = viewModel.program {
                joinBar(program)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .background(Color.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .task {
            if viewModel.program == nil {
                await viewModel.load()
            }
        }
        .fullScreenCover(isPresented: $showJoinedConfirmation) {
            if let program = viewModel.program {
                ProgramJoinedView(
                    program: program,
                    teamName: viewModel.category?.name,
                    members: viewModel.allMembers,
                    participantCount: viewModel.participantCount,
                    onCheckTeamBoard: { showJoinedConfirmation = false },
                    onFindOtherOpportunities: {
                        showJoinedConfirmation = false
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Banner

    /// Ordered banner images for the program — one renders as a still banner,
    /// several become a swipeable carousel with dots. Falls back to the single
    /// `bannerImageURL` for legacy payloads via `galleryImageURLs`.
    private var bannerURLs: [String] {
        viewModel.program?.galleryImageURLs ?? []
    }

    /// A single image renders as a still banner; two or more become a swipeable
    /// carousel with page dots. Never shows dots for one image.
    @ViewBuilder
    private var banner: some View {
        let urls = bannerURLs
        if urls.count > 1 {
            TabView(selection: $bannerSelection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    bannerImage(url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                PageDots(count: urls.count, selection: bannerSelection)
                    .padding(.bottom, 21)
            }
        } else {
            bannerImage(urls.first)
                .frame(height: 220)
                .contentShape(Rectangle())
                .clipped()
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous))
        }
    }

    private func bannerImage(_ url: String?) -> some View {
        Color.clear
            .overlay(
                AsyncImage(url: URL(string: url ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
            )
            .clipped()
    }

    private var topControls: some View {
        HStack {
            circleButton(systemName: "arrow.left") { dismiss() }

            Spacer()

            HStack(spacing: 17) {
                shareButton
                circleButton(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark") {
                    viewModel.toggleBookmark()
                }
            }
        }
    }

    /// Share the program via the system share sheet. Disabled until the program
    /// has loaded so there's something to share.
    @ViewBuilder
    private var shareButton: some View {
        if let program = viewModel.program {
            ShareLink(item: shareMessage(for: program)) {
                circleIcon(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        } else {
            circleButton(systemName: "square.and.arrow.up") {}
                .disabled(true)
                .opacity(0.5)
        }
    }

    private func shareMessage(for program: Program) -> String {
        "Check out \"\(program.name)\" on Volunteerly\n\n\(program.description)"
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circleIcon(systemName: systemName)
        }
        .buttonStyle(.plain)
    }

    private func circleIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.bodyStrong)
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 32, height: 32)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.program == nil {
            ContentUnavailableView("Couldn't load program", systemImage: "exclamationmark.triangle", description: Text(error))
                .padding(.top, 60)
        } else if let program = viewModel.program {
            VStack(alignment: .leading, spacing: 32) {
                overview(program)
                descriptionSection(program)
                membersSection
                if viewModel.isJoined {
                    MemberBoardSection(programId: programId, httpClient: httpClient)
                } else if let similar = viewModel.similarProgram {
                    similarSection(similar)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    // MARK: Overview (title + category + time/location boxes + map)

    private func overview(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(program.name)
                    .font(.sectionTitle)
                    .tracking(-0.3)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let category = viewModel.category {
                    categoryChips(category)
                }
            }

            mapCard
        }
    }

    /// Category pill(s) — gray rounded capsule with an emoji + label, matching
    /// the Figma chips (node 343:1288). The data model carries a single category
    /// today, so one pill renders; `FlowLayout` wraps cleanly if more are added.
    private func categoryChips(_ category: ProgramCategory) -> some View {
        FlowLayout(spacing: 9) {
            chip(emoji: Self.categoryEmoji(for: category.name), title: category.name)
        }
    }

    private func chip(emoji: String, title: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(title)
        }
        .font(.bodyText)
        .foregroundStyle(Theme.textPrimary)
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Emoji glyph paired with a category, mirroring the Figma chips. Matched on
    /// substrings so "Community Building" resolves the same as "Community".
    static func categoryEmoji(for category: String) -> String {
        let name = category.lowercased()
        switch true {
        case name.contains("environment"): return "🌱"
        case name.contains("community"):   return "👥"
        case name.contains("education"):   return "📚"
        case name.contains("health"):      return "❤️"
        case name.contains("animal"):      return "🐾"
        case name.contains("senior"):      return "🧓"
        case name.contains("food"):        return "🍽️"
        case name.contains("art"):         return "🎨"
        default:                           return "🏷️"
        }
    }

    // MARK: Map

    /// Map preview as a single rounded card (Figma node 390:1124): 211pt tall,
    /// 30pt corners and no fused "View Location" button — per the design system
    /// the card itself is the action, so tapping it opens Maps. Falls back to a
    /// neutral placeholder with a map glyph when the program has no coordinates.
    private var mapCard: some View {
        Button {
            openInMaps()
        } label: {
            mapTile
                .frame(height: 211)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(locationCoordinate == nil)
    }

    @ViewBuilder
    private var mapTile: some View {
        if let coordinate = locationCoordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))) {
                Marker(viewModel.location?.city ?? "", coordinate: coordinate)
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        } else {
            Rectangle()
                .fill(Theme.surface)
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(systemName: "map.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.black300)
                )
        }
    }

    private var locationCoordinate: CLLocationCoordinate2D? {
        guard let lat = viewModel.location?.latitude,
              let lon = viewModel.location?.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Opens the program's coordinate in Apple Maps.
    private func openInMaps() {
        guard let coordinate = locationCoordinate else { return }
        let mapItem: MKMapItem
        if #available(iOS 26.0, *) {
            mapItem = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        } else {
            mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
        mapItem.name = viewModel.location?.displayName ?? viewModel.location?.city
        mapItem.openInMaps()
    }

    // MARK: Description

    private func descriptionSection(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Figma node 343:1312 — "Description" is a plain 16 Regular label
            // here, not a section title.
            Text("Description")
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            Text(program.description)
                .font(.bodyText)
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surface)
                )
        }
    }

    // MARK: Members (host + other participants)

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Members")

            hostCard

            if !viewModel.otherMembers.isEmpty {
                memberAvatars
            }
        }
    }

    private var hostBio: String {
        viewModel.host?.occupation ?? viewModel.host?.goalText ?? "Host"
    }

    /// Host as a centered white card with a soft shadow (Figma node 343:1348):
    /// 114×126, circular avatar, name in bold and role beneath.
    private var hostCard: some View {
        VStack(spacing: 8) {
            Avatar(url: hostAvatarURL, size: 56)
            VStack(spacing: 2) {
                Text(viewModel.host?.fullName ?? "Host name")
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
                Text(hostBio)
                    .font(.subheadText)
                    .foregroundStyle(Theme.black500)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(width: 114, height: 126)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 30, x: 30, y: -30)
    }

    /// The host's profile photo URL, or `nil` so `Avatar` shows its silhouette.
    private var hostAvatarURL: URL? {
        guard let url = viewModel.host?.profileImageURL, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    /// Up to four member avatars from real participant profiles; when there are
    /// more, the last slot collapses into a "+N" overflow badge pinned to the
    /// trailing edge. Falls back to the silhouette when a member has no photo.
    private var memberAvatars: some View {
        let others = viewModel.otherMembers
        let maxVisible = 4
        return HStack(spacing: 18) {
            if others.count <= maxVisible {
                ForEach(others, id: \.userId) { member in
                    Avatar(url: avatarURL(member), size: 56)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(others.prefix(maxVisible - 1), id: \.userId) { member in
                    Avatar(url: avatarURL(member), size: 56)
                }
                Spacer(minLength: 0)
                overflowBadge(others.count - (maxVisible - 1))
            }
        }
    }

    /// A member's avatar URL, or `nil` (silhouette) when they have no photo.
    private func avatarURL(_ member: UserProfile) -> URL? {
        guard let url = member.profileImageURL, !url.isEmpty else { return nil }
        return URL(string: url)
    }

    private func overflowBadge(_ count: Int) -> some View {
        Circle()
            .fill(Color(.systemGray6))
            .frame(width: 56, height: 56)
            .overlay(
                Text("+\(count)")
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
            )
    }

    // MARK: Similar program nearby

    private func similarSection(_ similar: Program) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Similar programs nearby")
            NavigationLink(value: similar.id) {
                ProgramCard(program: similar, distanceKm: viewModel.similarDistanceKm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Join

    private func joinBar(_ program: Program) -> some View {
        Button {
            Task {
                let didJoin = await viewModel.toggleJoin()
                if didJoin {
                    withAnimation(.snappy) { showJoinedConfirmation = true }
                }
            }
        } label: {
            Text(joinLabel)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(!viewModel.canToggleJoin)
        .accessibilityLabel("\(joinLabel): \(viewModel.participantCount) of \(program.maxVolunteers) volunteers joined")
    }

    private var joinLabel: String {
        if viewModel.isJoined { return "Joined" }
        return viewModel.isFull ? "Program full" : "Join this program"
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.sectionHeader)
            .bold()
            .foregroundStyle(Theme.textPrimary)
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ProgramDetailView(programId: 1, httpClient: MockHTTPClient.shared)
            .navigationDestination(for: Int.self) { id in
                ProgramDetailView(programId: id, httpClient: MockHTTPClient.shared)
            }
    }
}
