import SwiftUI

struct MyProgramsView: View {
    @State private var viewModel: MyProgramsViewModel
    private let horizontalPadding: CGFloat = 20

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyProgramsViewModel(httpClient: httpClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VolunteerlyHeader()
                    Spacer()
                    NavigationLink(value: ProfileRoute()) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.textPrimary)
                    }
                    .accessibilityLabel("My page")
                }
                .padding(.horizontal, horizontalPadding)
                title
                searchRow
                tabBar
                content
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.programs.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Sections

    private var title: some View {
        Text("My Volunteer Programs")
            .font(.sectionHeader)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, horizontalPadding)
    }

    private var searchRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(.systemGray6), in: Capsule())

            Button {
                withAnimation(.snappy) { viewModel.pinnedOnly.toggle() }
            } label: {
                Text("Filter")
                    .font(.bodyText)
                    .foregroundStyle(viewModel.pinnedOnly ? Color.brand : Color.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private var tabBar: some View {
        HStack(spacing: 36) {
            ForEach(MyProgramsTab.allCases) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, horizontalPadding)
    }

    private func tabButton(_ tab: MyProgramsTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(.snappy) { viewModel.selectedTab = tab }
        } label: {
            VStack(spacing: 4) {
                Text(tab.rawValue)
                    .font(.bodyText)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.secondary)
                Rectangle()
                    .fill(isSelected ? Color.textPrimary : Color.clear)
                    .frame(height: 1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("Something went wrong", systemImage: "exclamationmark.triangle", description: Text(error))
                .padding(.top, 40)
        } else if viewModel.visiblePrograms.isEmpty {
            ContentUnavailableView("No Programs", systemImage: "calendar.badge.exclamationmark")
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.visiblePrograms) { program in
                    MyProgramRow(
                        program: program,
                        isPinned: viewModel.isPinned(program),
                        showsPin: viewModel.selectedTab == .active,
                        showsSubtitle: viewModel.selectedTab != .requested,
                        onTogglePin: { withAnimation(.snappy) { viewModel.togglePin(program) } }
                    )
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}

/// A single program row: thumbnail, name + blurb, and a pin toggle.
struct MyProgramRow: View {
    let program: Program
    let isPinned: Bool
    /// Past programs can't be pinned, so the affordance is hidden there.
    var showsPin: Bool = true
    /// Requested programs show the name only — no blurb.
    var showsSubtitle: Bool = true
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            NavigationLink(value: program.id) {
                HStack(spacing: 16) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        Text(program.name)
                            .font(.bodyStrong)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        if showsSubtitle {
                            Text(program.description)
                                .font(.buttonLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)

            if showsPin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 18))
                        .foregroundStyle(isPinned ? Color.textPrimary : Color.secondary.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPinned ? "Unpin program" : "Pin program")
            }
        }
    }

    private var thumbnail: some View {
        AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(Color(.systemGray5))
        }
        .frame(width: 69, height: 69)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        MyProgramsView(httpClient: MockHTTPClient.shared)
            .navigationDestination(for: Int.self) { id in
                ProgramDetailView(programId: id, httpClient: MockHTTPClient.shared)
            }
    }
}
