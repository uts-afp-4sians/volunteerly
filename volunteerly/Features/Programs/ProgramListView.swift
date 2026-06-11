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
                title
                searchRow
                categoryRow
                content
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
            .tabScrollTopAnchor()
        }
        .scrollsToTop(on: .programs)
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Categories load independently of the program list so a category
            // outage can't blank the list. Run both concurrently, then resolve
            // interests once the catalog is in.
            async let categoriesLoad: Void = viewModel.loadCategories()
            if viewModel.programs.isEmpty {
                await viewModel.load()
            }
            await categoriesLoad
            viewModel.applyUserInterests(profileStore.interests.map(\.name))
        }
        .refreshable {
            async let categoriesLoad: Void = viewModel.loadCategories()
            await viewModel.load()
            await categoriesLoad
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
        // Figma 86:642 — Large Title 32 Bold · Black/900 · tracking −0.5.
        Text("Find New Opportunities")
            .largeTitleStyle()
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
        // Figma 329:801 (FILTER-SEARCH) — 52pt tall, Black/50 fill, 30pt corners;
        // magnifier at x17 and "Search" at x44, both Black/500.
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(Theme.textMeta)
            TextField(
                "",
                text: $viewModel.searchQuery,
                prompt: Text("Search").foregroundColor(Theme.textMeta)
            )
            .font(.bodyText)
            .foregroundStyle(Theme.textBody)
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .onSubmit { Task { await viewModel.load() } }
        }
        .padding(.horizontal, 17)
        .frame(height: 52)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.iconPrimary)
                .frame(height: 52)
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
                // Categories load on their own track — show placeholder chips so
                // the filter row keeps its height instead of collapsing.
                if viewModel.categories.isEmpty && viewModel.isLoadingCategories {
                    ForEach(0..<6, id: \.self) { _ in
                        CategoryChipSkeleton()
                    }
                } else {
                    ForEach(viewModel.categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategoryIds.contains(category.id)
                        ) {
                            viewModel.toggleCategory(category.id)
                            Task { await viewModel.load() }
                        }
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
                        ProgramCard(
                            program: program,
                            distanceKm: program.distanceKm,
                            categoryEmoji: viewModel.categoryEmoji(for: program)
                        )
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
