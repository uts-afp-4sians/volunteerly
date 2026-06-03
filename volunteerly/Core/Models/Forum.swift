import Foundation

struct ForumPost: Identifiable, Codable {
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

struct ForumComment: Identifiable, Codable {
    let id: Int
    let postId: Int
    let authorUserId: Int
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "comment_id"
        case postId = "post_id"
        case authorUserId = "author_user_id"
        case body
        case createdAt = "created_at"
    }
}
