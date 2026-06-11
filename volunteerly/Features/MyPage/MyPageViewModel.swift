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

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// Loads the program pool. `BookmarksView` only needs `/programs` (it filters
    /// that pool by `bookmarkedProgramIds`), so it passes `includeMyPrograms:
    /// false` — otherwise a failure of the auth-gated `/me/programs` (expired
    /// token, cold-started backend) would blank the Bookmarks screen with
    /// "Something went wrong" even though its own data loaded fine.
    func load(includeMyPrograms: Bool = true) async {
        isLoading = true
        errorMessage = nil
        do {
            if includeMyPrograms {
                async let all: [Program] = httpClient.get("/programs")
                async let mine: [Program] = httpClient.get("/me/programs")
                programs = try await all
                myPrograms = try await mine
            } else {
                programs = try await httpClient.get("/programs")
            }
        } catch where error.isCancellation {
            // The view's `.task` was torn down mid-request (e.g. rapidly
            // switching away from the Bookmarks/My Page tab). Not a real
            // failure — keep the current data and surface no error, otherwise
            // the persisted view model flashes "Something went wrong" on return.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Slicing

    /// Bookmarked programs (from the shared `BookmarkStore`), soonest first.
    /// The store is the source of truth, so the cached `programs` pool is simply
    /// re-filtered whenever a bookmark toggles — no refetch needed.
    func bookmarkPrograms(bookmarkedIds: Set<Int>) -> [Program] {
        let list = filtered(programs) { bookmarkedIds.contains($0.id) }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    /// True once a joined program has finished — its end passed, or it was
    /// closed/cancelled. Active and Past split on this single predicate so every
    /// program `GET /me/programs` returns lands in exactly one bucket. An earlier
    /// Active allow-list (`endDatetime >= now && status ∈ {open, full}`) silently
    /// dropped a joined program in any other state — notably a `.draft` with a
    /// future end date — leaving it invisible in both lists.
    private func isPast(_ program: Program, now: Date) -> Bool {
        program.endDatetime < now || program.status == .closed || program.status == .cancelled
    }

    /// Joined, not-yet-finished programs, soonest first.
    var activePrograms: [Program] {
        let now = Date.now
        let list = filtered(myPrograms) { !isPast($0, now: now) }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    /// Joined programs that have already taken place (or were closed/cancelled).
    var pastPrograms: [Program] {
        let now = Date.now
        let list = filtered(myPrograms) { isPast($0, now: now) }
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
