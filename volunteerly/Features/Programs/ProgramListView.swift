import SwiftUI

struct ProgramListView: View {
    @State private var viewModel = ProgramListViewModel()
    @State private var showFilters = false

    private let horizontalPadding: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                title
                searchBar
                additionalFiltersButton
                categoryRow
                content
            }
            .padding(.vertical, 16)
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

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.systemGray6))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "hands.and.sparkles.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                )
            Text("Volunteerly")
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, horizontalPadding)
    }

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
            Image(systemName: "mic.fill")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(Color(.systemGray6), in: Capsule())
        .padding(.horizontal, horizontalPadding)
    }

    private var additionalFiltersButton: some View {
        Button {
            showFilters.toggle()
        } label: {
            Text("Additional filters")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, horizontalPadding)
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

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ProgramListView()
            .navigationDestination(for: Int.self) { id in
                ProgramDetailView(programId: id)
            }
    }
}
