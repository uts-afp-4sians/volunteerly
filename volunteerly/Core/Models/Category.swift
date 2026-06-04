import Foundation

nonisolated struct ProgramCategory: Identifiable, Codable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case name = "category_name"
    }
}

nonisolated struct Keyword: Identifiable, Codable {
    let id: Int
    let categoryId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "keyword_id"
        case categoryId = "category_id"
        case name = "keyword_name"
    }
}

/// Junction between a user and a keyword they're interested in (USER_INTEREST).
nonisolated struct UserInterest: Codable {
    let userId: Int
    let keywordId: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case keywordId = "keyword_id"
    }
}
