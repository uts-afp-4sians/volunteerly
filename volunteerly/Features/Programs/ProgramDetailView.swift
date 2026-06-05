import SwiftUI
import MapKit

struct ProgramDetailView: View {
    let programId: Int

    @State private var viewModel: ProgramDetailViewModel
    @State private var showJoinedConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private let horizontalPadding: CGFloat = 20

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.programId = programId
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
                    onMeetTheTeam: { showJoinedConfirmation = false },
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
                heading(program)
                descriptionSection(program)
                membersSection
                locationSection
                if !viewModel.isJoined, let similar = viewModel.similarProgram {
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

    // MARK: Heading (title + category + schedule)

    private func heading(_ program: Program) -> some View {
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
            schedule(program)
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

    private func schedule(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(
                icon: "clock",
                title: dayText(program.startDatetime),
                subtitle: "\(timeRange(program)) - \(temporalStatus(program))"
            )
            divider
            infoRow(
                icon: "mappin.and.ellipse",
                title: viewModel.location?.city ?? "Location to be announced",
                subtitle: locationSubtitle
            )
        }
    }

    private func infoRow(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var locationSubtitle: String? {
        guard let location = viewModel.location else { return nil }
        let parts = [location.stateRegion, location.country].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: Description

    private func descriptionSection(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Description")
            Text(program.description)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Members (host + other participants)

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Members")

            HStack(spacing: 16) {
                Avatar(url: URL(string: viewModel.host?.profileImageURL ?? ""), size: 63)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.host?.fullName ?? "Host name")
                        .font(.bodyStrong)
                        .foregroundStyle(Theme.textPrimary)
                    Text(hostBio)
                        .font(.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if viewModel.otherMemberCount > 0 {
                divider
                memberAvatars
            }
        }
    }

    private var hostBio: String {
        viewModel.host?.occupation ?? viewModel.host?.goalText ?? "Host"
    }

    /// Up to four member avatars; when there are more, the last slot collapses
    /// into a "+N" overflow badge. Placeholder circles until participant data is
    /// wired through.
    private var memberAvatars: some View {
        let others = viewModel.otherMemberCount
        let maxVisible = 4
        return HStack(spacing: 18) {
            if others <= maxVisible {
                ForEach(0..<others, id: \.self) { _ in
                    Avatar(source: .placeholder, size: 56)
                }
            } else {
                ForEach(0..<(maxVisible - 1), id: \.self) { _ in
                    Avatar(source: .placeholder, size: 56)
                }
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

    // MARK: Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("Location")
                Text(viewModel.location?.displayName ?? "Location to be announced")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            map
        }
    }

    @ViewBuilder
    private var map: some View {
        if let coordinate = locationCoordinate {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            ))) {
                Marker(viewModel.location?.city ?? "", coordinate: coordinate)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 179)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .allowsHitTesting(false)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(height: 179)
                .overlay(
                    Image(systemName: "map")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                )
        }
    }

    private var locationCoordinate: CLLocationCoordinate2D? {
        guard let lat = viewModel.location?.latitude,
              let lon = viewModel.location?.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: Similar program nearby

    private func similarSection(_ similar: Program) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Similar program nearby")
            NavigationLink(value: similar.id) {
                ProgramCard(program: similar, distanceKm: viewModel.similarDistanceKm)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Join

    private func joinBar(_ program: Program) -> some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    let didJoin = await viewModel.toggleJoin()
                    if didJoin {
                        withAnimation(.snappy) { showJoinedConfirmation = true }
                    }
                }
            } label: {
                Text(joinLabel)
                    .font(.actionButtonLabel)
                    .foregroundStyle(joinLabelColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 61)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canToggleJoin)
            .opacity(viewModel.canToggleJoin ? 1 : 0.5)

            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                Text("\(viewModel.participantCount)/\(program.maxVolunteers)")
                    .font(.bodyText)
            }
            .foregroundStyle(Theme.textPrimary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.participantCount) of \(program.maxVolunteers) volunteers joined")
        }
    }

    private var joinLabel: String {
        if viewModel.isJoined { return "Joined" }
        return viewModel.isFull ? "Full" : "Join"
    }

    private var joinLabelColor: Color {
        if viewModel.isJoined { return Theme.success }
        return viewModel.isFull ? Theme.textSecondary : Color.blue
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.sectionHeader)
            .bold()
            .foregroundStyle(Theme.textPrimary)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).year())
    }

    private func timeRange(_ program: Program) -> String {
        let start = program.startDatetime.formatted(date: .omitted, time: .shortened)
        let end = program.endDatetime.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    /// Where the event sits relative to now, surfaced beside the time range.
    private func temporalStatus(_ program: Program) -> String {
        let now = Date.now
        if program.startDatetime > now { return "upcoming" }
        if program.endDatetime < now { return "past" }
        return "ongoing"
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
