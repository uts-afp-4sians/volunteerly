import SwiftUI

struct ProgramListView: View {
    @State private var viewModel = ProgramListViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search programs...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading programs...")
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                    Spacer()
                } else if viewModel.filteredPrograms.isEmpty {
                    Spacer()
                    ContentUnavailableView("No Programs Found", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                } else {
                    List(viewModel.filteredPrograms) { program in
                        NavigationLink(value: program.id) {
                            // Reuse existing shared component
                            ProgramCard(program: program)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.fetchPrograms()
                    }
                }
            }
            .navigationTitle("Programs")
            .task {
                await viewModel.fetchPrograms()
            }
        }
    }
}

#Preview {
    // Add mock handlers to preview client
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return ProgramListView()
}
