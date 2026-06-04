import Foundation
import Observation

@Observable
final class ProgramListViewModel {
    var programs: [Program] = []
    var categories: [ProgramCategory] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedCategoryId: Int?

    var filteredPrograms: [Program] {
        programs.filter { program in
            let matchesCategory = selectedCategoryId == nil || program.categoryId == selectedCategoryId
            let matchesSearch = searchQuery.isEmpty
                || program.name.localizedCaseInsensitiveContains(searchQuery)
                || program.description.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = MockHTTPClient.shared) {
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            async let programs: [Program] = httpClient.get("/programs")
            async let categories: [ProgramCategory] = httpClient.get("/categories")
            self.programs = try await programs
            self.categories = try await categories
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleCategory(_ id: Int) {
        selectedCategoryId = (selectedCategoryId == id) ? nil : id
    }
}
