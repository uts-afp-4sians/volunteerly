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
    let bio: String?
    let instagram: String?
    let keySkills: String?
    let locationId: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case profileImageURL = "profile_image_url"
        case occupation
        case goalText = "goal_text"
        case bio
        case instagram
        case keySkills = "key_skills"
        case locationId = "location_id"
    }

    var fullName: String { "\(firstName) \(lastName)" }
}

/// Partial update body for `PATCH /me/profile`. Optionals that are `nil` are
/// omitted by the synthesized `encode` (`encodeIfPresent`), giving true PATCH
/// semantics — only set fields are written server-side.
nonisolated struct UserProfileUpdate: Codable {
    var firstName: String?
    var lastName: String?
    var occupation: String?
    var goalText: String?
    var bio: String?
    var instagram: String?
    var keySkills: String?
    /// Public CDN URL of the uploaded profile image. Set after a successful
    /// R2 presigned upload; `nil` means no change to the stored URL.
    var profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case occupation
        case goalText = "goal_text"
        case bio
        case instagram
        case keySkills = "key_skills"
        case profileImageUrl = "profile_image_url"
    }
}

/// A user's interest joined with its keyword name (`GET /me/interests`).
nonisolated struct UserInterestDetail: Codable, Identifiable {
    let keywordId: Int
    let keywordName: String

    var id: Int { keywordId }

    enum CodingKeys: String, CodingKey {
        case keywordId = "keyword_id"
        case keywordName = "keyword_name"
    }
}

/// Replace-set body for `PUT /me/interests`.
nonisolated struct UserInterestsUpdate: Codable {
    let keywordIds: [Int]

    enum CodingKeys: String, CodingKey {
        case keywordIds = "keyword_ids"
    }
}
