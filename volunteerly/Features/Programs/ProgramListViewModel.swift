import Foundation
import Observation

@MainActor
@Observable
final class ProgramListViewModel {
    var programs: [Program] = []
    var categories: [ProgramCategory] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedCategoryId: Int?

    // MARK: - Additional filters

    /// Bounds for the "Additional filters" sliders.
    let distanceRange: ClosedRange<Double> = 0...50    // km
    let memberRange: ClosedRange<Double> = 0...100

    /// Maximum distance in km. Stored for the UI; distance filtering is a no-op
    /// until programs carry a distance / the device location is available.
    var maxDistance: Double = 50
    /// Upper bound on a program's volunteer capacity. Defaults to the top of the
    /// range so nothing is filtered out until the user moves the slider.
    var memberCount: Double = 100

    var filteredPrograms: [Program] {
        programs.filter { program in
            let matchesCategory = selectedCategoryId == nil || program.categoryId == selectedCategoryId
            let matchesSearch = searchQuery.isEmpty
                || program.name.localizedCaseInsensitiveContains(searchQuery)
                || program.description.localizedCaseInsensitiveContains(searchQuery)
            let matchesMembers = memberCount >= memberRange.upperBound
                || Double(program.maxVolunteers) <= memberCount
            return matchesCategory && matchesSearch && matchesMembers
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
