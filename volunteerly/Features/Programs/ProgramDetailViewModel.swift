import Foundation
import Observation

@MainActor
@Observable
final class ProgramDetailViewModel {
    let programId: Int

    var program: Program?
    var host: UserProfile?
    var location: Location?
    var category: ProgramCategory?
    var isLoading = false
    var errorMessage: String?

    var isBookmarked = false
    var isJoined = false

    private let httpClient: HTTPClient

    init(programId: Int, httpClient: HTTPClient = MockHTTPClient.shared) {
        self.programId = programId
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let program: Program = try await httpClient.get("/programs/\(programId)")
            self.program = program
            // Host and location are supplementary — a missing one shouldn't fail the screen.
            async let host: UserProfile = httpClient.get("/users/\(program.creatorUserId)/profile")
            async let location: Location = httpClient.get("/locations/\(program.locationId)")
            async let categories: [ProgramCategory] = httpClient.get("/categories")
            self.host = try? await host
            self.location = try? await location
            self.category = (try? await categories)?.first { $0.id == program.categoryId }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleBookmark() { isBookmarked.toggle() }
    func toggleJoin() { isJoined.toggle() }
}
