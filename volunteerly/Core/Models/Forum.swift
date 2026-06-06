import Foundation

/// A question on a program's Member board. `Hashable` so it can drive a
/// `NavigationLink(value:)` straight to the forum thread.
nonisolated struct ForumPost: Identifiable, Codable, Hashable {
    let id: Int
    let programId: Int
    let authorUserId: Int
    let title: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "post_id"
        case programId = "program_id"
        case authorUserId = "author_user_id"
        case title
        case body
        case createdAt = "created_at"
    }
}

nonisolated struct ForumComment: Identifiable, Codable {
    let id: Int
    let postId: Int
    let authorUserId: Int
    let body: String
    let createdAt: Date
    /// Set when this comment is a reply to another comment; `nil` for a
    /// top-level comment. The backend doesn't send this yet, so it decodes to
    /// `nil` (every comment is treated as a root) and stays forward-compatible
    /// once threaded replies ship.
    let parentCommentId: Int?
    /// Like tally. Absent on the current API — read it via `?? 0`.
    let likeCount: Int?
    /// Whether the signed-in user has liked it. Absent on the current API.
    let likedByMe: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "comment_id"
        case postId = "post_id"
        case authorUserId = "author_user_id"
        case body
        case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
    }
}
