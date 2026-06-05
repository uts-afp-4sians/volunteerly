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
    var similarProgram: Program?
    var isLoading = false
    var errorMessage: String?

    var isBookmarked = false
    var isJoined = false

    /// Approximate "filled" spots. Real participation data isn't wired yet, so
    /// we model a program at ~60% capacity for the Members grid and the Join
    /// counter; joining bumps the count by one (capped at capacity).
    var baseParticipantCount: Int {
        guard let max = program?.maxVolunteers, max > 0 else { return 0 }
        return Swift.max(1, Int((Double(max) * 0.6).rounded()))
    }

    /// Current participant count reflected in the Join counter.
    var participantCount: Int {
        guard let max = program?.maxVolunteers else { return 0 }
        return min(max, baseParticipantCount + (isJoined ? 1 : 0))
    }

    /// Members other than the host, used to drive the avatar row.
    var otherMemberCount: Int { Swift.max(0, baseParticipantCount - 1) }

    private let httpClient: HTTPClient

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
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
            async let allPrograms: [Program] = httpClient.get("/programs")
            self.host = try? await host
            self.location = try? await location
            self.category = (try? await categories)?.first { $0.id == program.categoryId }

            // Pick a nearby program to suggest — prefer the same category, then
            // fall back to any other program.
            let others = ((try? await allPrograms) ?? []).filter { $0.id != program.id }
            self.similarProgram = others.first { $0.categoryId == program.categoryId } ?? others.first
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleBookmark() { isBookmarked.toggle() }
    func toggleJoin() { isJoined.toggle() }
}
