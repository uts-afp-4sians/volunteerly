import Foundation
import Observation

/// Backs the "My program" section of `MyPageView` (active + Past lists) and the
/// standalone `BookmarksView`. Loads the volunteer's programs and slices them by
/// state, applying the search filter.
@MainActor
@Observable
final class MyPageViewModel {
    /// Every listed program — the candidate pool for bookmarks.
    var programs: [Program] = []
    /// Programs the signed-in user actually joined (or hosts), straight from
    /// `GET /me/programs`; the active/Past slices read from this list.
    var myPrograms: [Program] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""

    /// Programs the volunteer has bookmarked. Seeded so the Bookmarks screen
    /// demonstrates content out of the box.
    var bookmarkedProgramIds: Set<Int> = [1, 2]

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let all: [Program] = httpClient.get("/programs")
            async let mine: [Program] = httpClient.get("/me/programs")
            programs = try await all
            myPrograms = try await mine
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Bookmarks

    func isBookmarked(_ program: Program) -> Bool {
        bookmarkedProgramIds.contains(program.id)
    }

    func toggleBookmark(_ program: Program) {
        if bookmarkedProgramIds.contains(program.id) {
            bookmarkedProgramIds.remove(program.id)
        } else {
            bookmarkedProgramIds.insert(program.id)
        }
    }

    // MARK: - Slicing

    /// Bookmarked programs, soonest first.
    var bookmarkPrograms: [Program] {
        let list = filtered(programs) { self.isBookmarked($0) }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    /// Joined, not-yet-finished programs, soonest first.
    var activePrograms: [Program] {
        let now = Date.now
        let list = filtered(myPrograms) { program in
            program.endDatetime >= now && (program.status == .open || program.status == .full)
        }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    /// Joined programs that have already taken place (or were closed/cancelled).
    var pastPrograms: [Program] {
        let now = Date.now
        let list = filtered(myPrograms) { program in
            program.endDatetime < now || program.status == .closed || program.status == .cancelled
        }
        return list.sorted { $0.startDatetime > $1.startDatetime }
    }

    private func filtered(
        _ source: [Program], _ predicate: (Program) -> Bool
    ) -> [Program] {
        source.filter { program in
            guard predicate(program) else { return false }
            guard !searchQuery.isEmpty else { return true }
            let inName = program.name.localizedCaseInsensitiveContains(searchQuery)
            let inDescription = program.description.localizedCaseInsensitiveContains(searchQuery)
            return inName || inDescription
        }
    }
}
