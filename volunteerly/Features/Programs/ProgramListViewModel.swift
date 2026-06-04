import Foundation
import Observation

@Observable
final class ProgramListViewModel {
    var programs: [Program] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    
    var filteredPrograms: [Program] {
        if searchQuery.isEmpty {
            return programs
        } else {
            return programs.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) || $0.description.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient = MockHTTPClient.shared) {
        self.httpClient = httpClient
    }
    
    func fetchPrograms() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch list of programs
            self.programs = try await httpClient.get("/programs")
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
