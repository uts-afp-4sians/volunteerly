import SwiftUI

struct ProgramListView: View {
    @Environment(UserProfileStore.self) private var profileStore

    @State private var viewModel: ProgramListViewModel
    @State private var showFilters = false
    private let refreshID: Int
    private let horizontalPadding: CGFloat = 20

    init(
        httpClient: HTTPClient = LiveHTTPClient.shared,
        refreshID: Int = 0
    ) {
        _viewModel = State(initialValue: ProgramListViewModel(httpClient: httpClient))
        self.refreshID = refreshID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VolunteerlyHeader()
                    .padding(.horizontal, horizontalPadding)
                title
                searchRow
                categoryRow
                content
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
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
        .onChange(of: refreshID) { _, _ in
            Task {
                await viewModel.load()
                viewModel.applyUserInterests(profileStore.interests.map(\.name))
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(viewModel: viewModel) {
                showFilters = false
                Task { await viewModel.load() }
            }
            .presentationDetents([.fraction(0.7)])
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

    private var searchRow: some View {
        HStack(spacing: 16) {
            searchBar
            filterButton
        }
        .padding(.horizontal, horizontalPadding)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.load() } }
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(Color(.systemGray6), in: Capsule())
    }

    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(height: 42)
                .overlay(alignment: .topTrailing) {
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 8, height: 8)
                            .offset(x: 5, y: -3)
                    }
                }
                .contentShape(Rectangle())
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
                        Task { await viewModel.load() }
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
                        ProgramCard(program: program, distanceKm: program.distanceKm)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
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
