import Foundation
import Observation

/// Single source of truth for which programs the signed-in user has bookmarked.
///
/// Shared across the app via `.environment` so the Bookmarks list and a program's
/// detail screen read and write the *same* set — toggling the bookmark on the
/// detail screen updates the list instantly, with no refetch. The Bookmarks list
/// can therefore cache its program pool and simply re-derive its filtered view
/// whenever this set changes.
///
/// Currently in-memory and seeded for the demo. Persistence is a follow-up:
/// hydrate from `GET /me/bookmarks` and sync toggles to
/// `POST/DELETE /programs/{id}/bookmark` (the `program_bookmarks` table exists).
@MainActor
@Observable
final class BookmarkStore {
    /// Program ids the user has bookmarked.
    private(set) var ids: Set<Int>

    // TODO(oma-deferred): seed from GET /me/bookmarks once the endpoint exists.
    init(ids: Set<Int> = [1, 2]) {
        self.ids = ids
    }

    func isBookmarked(_ programId: Int) -> Bool {
        ids.contains(programId)
    }

    func isBookmarked(_ program: Program) -> Bool {
        ids.contains(program.id)
    }

    /// Flip the bookmark for a program and return the new state.
    @discardableResult
    func toggle(_ programId: Int) -> Bool {
        if ids.contains(programId) {
            ids.remove(programId)
            return false
        }
        ids.insert(programId)
        return true
    }
}
