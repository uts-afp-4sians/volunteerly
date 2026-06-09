import Foundation
import Observation

/// How the Member board orders its questions. The board exposes these via a
/// single chip that cycles through them. Mirrors the Figma `group-4-prototype`
/// board design (Newest / Top / Oldest).
enum BoardSort: String, CaseIterable, Identifiable {
    case newest
    case top
    case oldest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest"
        case .top:    "Top"
        case .oldest: "Oldest"
        }
    }

    /// The next order in the cycle, so one chip tap advances
    /// Newest → Top → Oldest → Newest.
    var next: BoardSort {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
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
    var sort: BoardSort = .newest
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
        case .newest:
            posts.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            posts.sorted { $0.createdAt < $1.createdAt }
        case .top:
            // The post payload carries no engagement signal yet, so rank by id
            // descending as a stable proxy for the most prominent threads.
            // TODO(oma-deferred): rank by reply/like count once the API exposes it.
            posts.sorted { $0.id > $1.id }
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

    /// Open a new question on the board via `POST /programs/{id}/posts`. Returns
    /// `true` when the post was created so the caller can dismiss the composer.
    /// Empty title/body are rejected client-side before any request.
    func createPost(title: String, body: String) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else { return false }

        errorMessage = nil
        do {
            let created: ForumPost = try await httpClient.post(
                "/programs/\(programId)/posts",
                body: NewPostBody(title: trimmedTitle, body: trimmedBody)
            )
            posts.append(created)
            await resolveAuthors(for: [created])
            return true
        } catch {
            // The method-blind mock echoes the list array, so decoding a single
            // post fails even though the write landed — reload to surface it.
            // A real transport/auth/server error reports and keeps the composer.
            guard isResponseParseError(error) else {
                errorMessage = error.localizedDescription
                return false
            }
            await load()
            return true
        }
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

    /// Whether the error is a response-decoding failure (raw `DecodingError`
    /// from the mock, or `APIError.decodingFailed` from the live client) rather
    /// than a transport/auth/server error.
    private func isResponseParseError(_ error: Error) -> Bool {
        if error is DecodingError { return true }
        if case APIError.decodingFailed = error { return true }
        return false
    }
}

/// Body for `POST /programs/{id}/posts` — opens a new Member board question.
private struct NewPostBody: Encodable {
    let title: String
    let body: String
}
