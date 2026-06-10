import SwiftUI
import MapKit

struct ProgramDetailView: View {
    let programId: Int

    @State private var viewModel: ProgramDetailViewModel
    @State private var showJoinedConfirmation = false
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
                    goal: viewModel.category?.name,
                    teammateCount: program.maxVolunteers,
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

    private var banner: some View {
        Color.clear
            .overlay(
                AsyncImage(url: URL(string: viewModel.program?.bannerImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
            )
            .frame(height: 220)
            .contentShape(Rectangle())
            .clipped()
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                PageDots(count: 3, selection: 0)
                    .padding(.bottom, 21)
            }
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
                joinBar(program)
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
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let category = viewModel.category {
                    categoryChip(category)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                infoBox(
                    icon: "clock",
                    title: dayText(program.startDatetime),
                    subtitle: timeRange(program)
                )
                infoBox(
                    icon: "mappin.and.ellipse",
                    title: viewModel.location?.city ?? "Location to be announced",
                    subtitle: locationSubtitle
                )
            }

            mapCard
        }
    }

    private func categoryChip(_ category: ProgramCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: CategoryChip.symbolName(for: category.name))
                .font(.system(size: 14))
            Text(category.name)
                .font(.bodyText)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: Capsule())
    }

    /// Outlined information box used for the schedule and location summaries.
    private func infoBox(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.bodyText)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private var locationSubtitle: String? {
        guard let location = viewModel.location else { return nil }
        let parts = [location.stateRegion, location.country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: Map + View Location

    /// Map preview with the green "View Location" action fused to its lower edge,
    /// the two clipped together as a single rounded card.
    private var mapCard: some View {
        VStack(spacing: 0) {
            mapTile
                .frame(height: 179)

            Button {
                openInMaps()
            } label: {
                Text("View Location")
                    .font(.buttonLabel)
                    .foregroundStyle(Color.onBrand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.brand)
            }
            .buttonStyle(.plain)
            .disabled(locationCoordinate == nil)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .fill(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(systemName: "map")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(uiColor: .systemGray3))
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
        let mapItem = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        mapItem.name = viewModel.location?.displayName ?? viewModel.location?.city
        mapItem.openInMaps()
    }

    // MARK: Description

    private func descriptionSection(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Description")
            Text(program.description)
                .font(.bodyText)
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.systemGray6))
                )
        }
    }

    // MARK: Members (host + other participants)

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Members")

            VStack(alignment: .leading, spacing: 10) {
                hostAvatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.host?.fullName ?? "Host name")
                        .font(.bodyStrong)
                        .foregroundStyle(Theme.textPrimary)
                    Text(hostBio)
                        .font(.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if viewModel.otherMemberCount > 0 {
                memberAvatars
            }
        }
    }

    private var hostBio: String {
        viewModel.host?.occupation ?? viewModel.host?.goalText ?? "Host"
    }

    /// Rounded-square host avatar, falling back to the person silhouette when no
    /// profile image is available.
    private var hostAvatar: some View {
        let size: CGFloat = 96
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
            .frame(width: size, height: size)
            .overlay {
                AsyncImage(url: URL(string: viewModel.host?.profileImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(Color(uiColor: .systemGray3))
                        .frame(width: size * 0.55)
                        .offset(y: size * 0.13)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Up to four member avatars; when there are more, the last slot collapses
    /// into a "+N" overflow badge pinned to the trailing edge. Placeholder
    /// circles until participant data is wired through.
    private var memberAvatars: some View {
        let others = viewModel.otherMemberCount
        let maxVisible = 4
        return HStack(spacing: 18) {
            if others <= maxVisible {
                ForEach(0..<others, id: \.self) { _ in
                    Avatar(source: .placeholder, size: 56)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(0..<(maxVisible - 1), id: \.self) { _ in
                    Avatar(source: .placeholder, size: 56)
                }
                Spacer(minLength: 0)
                overflowBadge(others - (maxVisible - 1))
            }
        }
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

    private func dayText(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    /// "Thursday 11 June 2026" — day-first, full month, no commas, matching the
    /// schedule box in the Figma design.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter
    }()

    private func timeRange(_ program: Program) -> String {
        let start = program.startDatetime.formatted(date: .omitted, time: .shortened)
        let end = program.endDatetime.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
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
