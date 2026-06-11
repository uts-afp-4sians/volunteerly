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
/// Hydrated from `GET /me/bookmarks` at launch; toggles update the set
/// optimistically and sync to `POST/DELETE /programs/{id}/bookmark`, reverting on
/// failure so the UI never drifts from the server.
@MainActor
@Observable
final class BookmarkStore {
    /// Program ids the user has bookmarked.
    private(set) var ids: Set<Int>

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LiveHTTPClient.shared, ids: Set<Int> = []) {
        self.httpClient = httpClient
        self.ids = ids
    }

    /// Hydrate the set from the server. Cache-friendly to call at the app root;
    /// failures (offline, cancellation) leave the current set untouched.
    func load() async {
        do {
            let programs: [Program] = try await httpClient.get("/me/bookmarks")
            ids = Set(programs.map(\.id))
        } catch where error.isCancellation {
            // View teardown cancelled the request — not a failure.
        } catch {
            // Bookmarks are non-critical; keep whatever we already have.
        }
    }

    func isBookmarked(_ programId: Int) -> Bool {
        ids.contains(programId)
    }

    func isBookmarked(_ program: Program) -> Bool {
        ids.contains(program.id)
    }

    /// Optimistically flip the bookmark and persist it; returns the new state.
    @discardableResult
    func toggle(_ programId: Int) -> Bool {
        let nowBookmarked = !ids.contains(programId)
        if nowBookmarked { ids.insert(programId) } else { ids.remove(programId) }
        Task { await sync(programId, bookmarked: nowBookmarked) }
        return nowBookmarked
    }

    private func sync(_ programId: Int, bookmarked: Bool) async {
        do {
            if bookmarked {
                try await httpClient.postExpectingNoContent(
                    "/programs/\(programId)/bookmark", body: EmptyBody()
                )
            } else {
                try await httpClient.delete("/programs/\(programId)/bookmark")
            }
        } catch where error.isCancellation {
            // Ignore — a cancelled sync leaves the optimistic state as-is.
        } catch {
            // Roll back so the UI matches the server.
            if bookmarked { ids.remove(programId) } else { ids.insert(programId) }
        }
    }
}

private struct EmptyBody: Encodable {}
