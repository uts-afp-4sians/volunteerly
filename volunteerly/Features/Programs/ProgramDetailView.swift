import SwiftUI
import MapKit

struct ProgramDetailView: View {
    let programId: Int

    @State private var viewModel: ProgramDetailViewModel
    @State private var showJoinedConfirmation = false
    @Environment(\.dismiss) private var dismiss

    private let horizontalPadding: CGFloat = 20

    init(programId: Int) {
        self.programId = programId
        _viewModel = State(initialValue: ProgramDetailViewModel(programId: programId))
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
                pageDots
                    .padding(.bottom, 18)
            }
    }

    private var pageDots: some View {
        HStack(spacing: 17) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.white.opacity(index == 0 ? 0.9 : 0.5))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private var topControls: some View {
        HStack {
            circleButton(systemName: "arrow.left") { dismiss() }

            Spacer()

            HStack(spacing: 17) {
                circleButton(systemName: "square.and.arrow.up") {}
                circleButton(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark") {
                    viewModel.toggleBookmark()
                }
            }
        }
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
                locationSection
                opportunitySection(program)
                hostSection
                participantGrid
                joinButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        }
    }

    private func heading(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(program.name)
                .font(.subheading)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Text(program.description)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.sectionHeader)
                    .bold()
                    .foregroundStyle(Theme.textPrimary)
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

    // MARK: Upcoming opportunity

    private func opportunitySection(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            divider
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming volunteer opportunities")
                        .font(.bodyText)
                        .foregroundStyle(Color.blue)
                    Text("\(dayText(program.startDatetime))\n\(timeRange(program))")
                        .font(.bodyText)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 12)
                Text("Occurs every \(weekdayShort(program.startDatetime))")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 16)
            divider
        }
    }

    // MARK: About host

    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About Host")
                .font(.sectionHeader)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: viewModel.host?.profileImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 63, height: 63)
                .clipShape(Circle())

                Text(viewModel.host?.fullName ?? "User name")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
            }
            divider
        }
    }

    // MARK: Participants

    /// Placeholder participant avatars. Real participant data isn't wired yet,
    /// so this mirrors the design's avatar grid using the program's capacity.
    private var participantGrid: some View {
        let count = min(viewModel.program?.maxVolunteers ?? 0, 8)
        let columns = [GridItem(.adaptive(minimum: 56, maximum: 56), spacing: 18, alignment: .leading)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
            }
        }
    }

    // MARK: Join

    private var joinButton: some View {
        Button {
            withAnimation(.snappy) { viewModel.toggleJoin() }
            if viewModel.isJoined { showJoinedConfirmation = true }
        } label: {
            Text(viewModel.isJoined ? "Joined" : "Join")
                .font(.actionButtonLabel)
                .foregroundStyle(viewModel.isJoined ? Theme.success : Color.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 61)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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

    private func weekdayShort(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ProgramDetailView(programId: 1)
    }
}
