import Foundation
import Observation

/// How the Member board orders its questions. Mirrors the four sort chips in
/// the Figma `group-4-prototype` board design.
enum BoardSort: String, CaseIterable, Identifiable {
    case dateAscending
    case dateDescending
    case authorAZ
    case authorZA

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAscending:  "Date created (ascending)"
        case .dateDescending: "Date created (descending)"
        case .authorAZ:       "Author (A-Z)"
        case .authorZA:       "Author (Z-A)"
        }
    }
}

/// Drives the Member board section: loads a program's forum posts, resolves
/// author names (best-effort) and applies the selected sort chip.
@MainActor
@Observable
final class MemberBoardViewModel {
    let programId: Int

    private(set) var posts: [ForumPost] = []
    /// Display name per author id, resolved best-effort from user profiles.
    private(set) var authorNames: [Int: String] = [:]
    var sort: BoardSort = .dateDescending
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let httpClient: HTTPClient

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.programId = programId
        self.httpClient = httpClient
    }

    /// A readable author name, falling back to the id when the profile is
    /// unavailable (the board card itself doesn't show it, but the author
    /// sort chips rely on it).
    func authorName(for post: ForumPost) -> String {
        authorNames[post.authorUserId] ?? "Member \(post.authorUserId)"
    }

    /// Posts arranged by the selected sort chip.
    var sortedPosts: [ForumPost] {
        switch sort {
        case .dateAscending:
            posts.sorted { $0.createdAt < $1.createdAt }
        case .dateDescending:
            posts.sorted { $0.createdAt > $1.createdAt }
        case .authorAZ:
            posts.sorted { authorName(for: $0).localizedCaseInsensitiveCompare(authorName(for: $1)) == .orderedAscending }
        case .authorZA:
            posts.sorted { authorName(for: $0).localizedCaseInsensitiveCompare(authorName(for: $1)) == .orderedDescending }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let posts: [ForumPost] = try await httpClient.get("/programs/\(programId)/posts")
            self.posts = posts
            await resolveAuthors(for: posts)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Look up the display name for every distinct author we haven't seen yet.
    /// A missing profile is non-fatal — the card text doesn't depend on it.
    private func resolveAuthors(for posts: [ForumPost]) async {
        let ids = Set(posts.map(\.authorUserId)).subtracting(authorNames.keys)
        for id in ids {
            if let profile: UserProfile = try? await httpClient.get("/users/\(id)/profile") {
                authorNames[id] = profile.fullName
            }
        }
    }
}
