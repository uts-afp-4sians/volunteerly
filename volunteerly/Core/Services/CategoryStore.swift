import Foundation

/// Session-wide cache for the program category catalog (`GET /categories`).
///
/// The catalog rarely changes, but three screens (program list, program detail,
/// post/edit form) each fetched it on every appearance because their view
/// models live and die with the screen. This store serves a cached copy for an
/// hour and coalesces concurrent callers into a single in-flight request.
///
/// In-memory only: the payload is tiny, so refetching once per launch is fine
/// and avoids any disk-staleness concerns. Entries are keyed per `HTTPClient`
/// instance so previews/tests on `MockHTTPClient` never mix with live data —
/// this relies on clients being shared class instances (`LiveHTTPClient.shared`
/// / `MockHTTPClient.shared`), which both conformers are.
@MainActor
final class CategoryStore {
    static let shared = CategoryStore()

    /// How long a fetched catalog stays fresh before the next ask refetches.
    private let ttl: TimeInterval = 60 * 60

    private struct Entry {
        let categories: [ProgramCategory]
        let fetchedAt: Date
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private var inFlight: [ObjectIdentifier: Task<[ProgramCategory], Error>] = [:]

    /// The still-fresh cached catalog for this client, without fetching.
    /// Lets view models seed their `categories` synchronously at init so a
    /// cache-hit session never flashes loading skeletons for even a frame.
    func cached(httpClient: HTTPClient = LiveHTTPClient.shared) -> [ProgramCategory]? {
        let key = ObjectIdentifier(httpClient as AnyObject)
        guard let entry = entries[key], Date().timeIntervalSince(entry.fetchedAt) < ttl
        else { return nil }
        return entry.categories
    }

    func categories(httpClient: HTTPClient = LiveHTTPClient.shared) async throws -> [ProgramCategory] {
        let key = ObjectIdentifier(httpClient as AnyObject)

        if let entry = entries[key], Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.categories
        }
        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task<[ProgramCategory], Error> {
            try await httpClient.get("/categories") as [ProgramCategory]
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let categories = try await task.value
        entries[key] = Entry(categories: categories, fetchedAt: Date())
        return categories
    }
}
