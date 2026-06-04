import Foundation

nonisolated struct User: Identifiable, Codable {
    let id: Int
    let email: String
    let isDeleted: Bool
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case email
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

nonisolated struct UserProfile: Codable {
    let userId: Int
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
    let profileImageURL: String?
    let occupation: String?
    let goalText: String?
    let locationId: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case profileImageURL = "profile_image_url"
        case occupation
        case goalText = "goal_text"
        case locationId = "location_id"
    }

    var fullName: String { "\(firstName) \(lastName)" }
}
