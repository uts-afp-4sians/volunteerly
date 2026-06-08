import SwiftUI

struct ProgramListView: View {
    @Environment(UserProfileStore.self) private var profileStore

    @State private var viewModel: ProgramListViewModel
    @State private var showFilters = false
    private let horizontalPadding: CGFloat = 20

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: ProgramListViewModel(httpClient: httpClient))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VolunteerlyHeader()
                        .padding(.horizontal, horizontalPadding)
                    title
                    searchBar
                    additionalFilters
                    categoryRow
                    content
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.programs.isEmpty {
                    await viewModel.load()
                }
                viewModel.applyUserInterests(profileStore.interests.map(\.name))
            }
            .refreshable {
                await viewModel.load()
                viewModel.applyUserInterests(profileStore.interests.map(\.name))
            }
            .onChange(of: profileStore.interests) { _, _ in
                viewModel.applyUserInterests(profileStore.interests.map(\.name))
            }

            // Floating Action Button (FAB)
            NavigationLink {
                PostProgramView(onCreated: { Task { await viewModel.load() } })
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(FABButtonStyle())
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Sections

    private var title: some View {
        Text("Find New\nOpportunities")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, horizontalPadding)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            MicButton(text: $viewModel.searchQuery)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(Color(.systemGray6), in: Capsule())
        .padding(.horizontal, horizontalPadding)
    }

    @ViewBuilder
    private var additionalFilters: some View {
        additionalFiltersButton
            .overlay(alignment: .top) {
                if showFilters {
                    AdditionalFiltersPanel(
                        maxDistance: $viewModel.maxDistance,
                        memberCount: $viewModel.memberCount,
                        distanceRange: viewModel.distanceRange,
                        memberRange: viewModel.memberRange,
                        onToggle: { withAnimation(.snappy) { showFilters = false } }
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, horizontalPadding)
            .zIndex(1)
    }

    private var additionalFiltersButton: some View {
        Button {
            withAnimation(.snappy) { showFilters = true }
        } label: {
            Text("Additional filters")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 17) {
                ForEach(viewModel.categories) { category in
                    CategoryChip(
                        category: category,
                        isSelected: viewModel.selectedCategoryId == category.id
                    ) {
                        viewModel.toggleCategory(category.id)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
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
        } else if viewModel.filteredPrograms.isEmpty {
            ContentUnavailableView("No Programs Found", systemImage: "calendar.badge.exclamationmark")
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 21) {
                ForEach(viewModel.filteredPrograms) { program in
                    NavigationLink(value: program.id) {
                        ProgramCard(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}

struct FABButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var environmentFocused

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let isFocused = environmentFocused

        configuration.label
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color.onBrand)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(isPressed ? Color.brandDark : Color.brand)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .overlay(
                Circle()
                    .strokeBorder(Color.brand, lineWidth: isFocused ? 2 : 0)
                    .padding(-4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ProgramListView(httpClient: MockHTTPClient.shared)
            .navigationDestination(for: Int.self) { id in
                ProgramDetailView(programId: id, httpClient: MockHTTPClient.shared)
            }
    }
    .environment(UserProfileStore())
}
