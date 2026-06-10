import Foundation
import Observation

/// The two segments of the "My program" section on the My page screen.
enum MyPageProgramTab: String, CaseIterable, Identifiable {
    /// Joined programs that haven't finished yet.
    case active = "Active"
    /// Programs the volunteer has bookmarked.
    case bookmark = "Bookmark"

    var id: String { rawValue }
}

/// Backs the "My program" section of `MyPageView`: loads the volunteer's
/// programs and slices them into the Active / Bookmark tabs (with a "Past"
/// sub-list under Active), applying the search filter.
@MainActor
@Observable
final class MyPageViewModel {
    var programs: [Program] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedTab: MyPageProgramTab = .active

    /// Programs the volunteer has bookmarked. Seeded so the Bookmark tab
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
            programs = try await httpClient.get("/programs")
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

    /// Currently joined, not-yet-finished programs, soonest first.
    var activePrograms: [Program] {
        let now = Date.now
        let list = filtered { program in
            program.endDatetime >= now && (program.status == .open || program.status == .full)
        }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    /// Programs that have already taken place (or were closed/cancelled).
    var pastPrograms: [Program] {
        let now = Date.now
        let list = filtered { program in
            program.endDatetime < now || program.status == .closed || program.status == .cancelled
        }
        return list.sorted { $0.startDatetime > $1.startDatetime }
    }

    /// Bookmarked programs, soonest first.
    var bookmarkPrograms: [Program] {
        let list = filtered { self.isBookmarked($0) }
        return list.sorted { $0.startDatetime < $1.startDatetime }
    }

    private func filtered(_ predicate: (Program) -> Bool) -> [Program] {
        programs.filter { program in
            guard predicate(program) else { return false }
            guard !searchQuery.isEmpty else { return true }
            let inName = program.name.localizedCaseInsensitiveContains(searchQuery)
            let inDescription = program.description.localizedCaseInsensitiveContains(searchQuery)
            return inName || inDescription
        }
    }
}
