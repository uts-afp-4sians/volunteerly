import Foundation

struct ProgramCategory: Identifiable, Codable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case name = "category_name"
    }
}

struct Keyword: Identifiable, Codable {
    let id: Int
    let categoryId: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "keyword_id"
        case categoryId = "category_id"
        case name = "keyword_name"
    }
}
