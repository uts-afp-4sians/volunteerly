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
    /// Location embedded like interests — one profile read hydrates the city
    /// shown on My Page without a second `/locations/{id}` call.
    var location: Location?
    /// Interests embedded in the profile resource — a single read hydrates the
    /// whole screen, so the client never makes a second `/me/interests` call.
    var interests: [UserInterestDetail] = []

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
        case location
        case interests
    }

    var fullName: String { "\(firstName) \(lastName)" }
}

extension UserProfile {
    /// Custom decode (in an extension, so the memberwise initializer is kept)
    /// that tolerates a missing `interests` key — decoding to `[]` instead of
    /// throwing. Keeps cached blobs and any not-yet-migrated response decodable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int.self, forKey: .userId)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        profileImageURL = try container.decodeIfPresent(String.self, forKey: .profileImageURL)
        occupation = try container.decodeIfPresent(String.self, forKey: .occupation)
        goalText = try container.decodeIfPresent(String.self, forKey: .goalText)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        instagram = try container.decodeIfPresent(String.self, forKey: .instagram)
        keySkills = try container.decodeIfPresent(String.self, forKey: .keySkills)
        locationId = try container.decodeIfPresent(Int.self, forKey: .locationId)
        location = try container.decodeIfPresent(Location.self, forKey: .location)
        interests = try container.decodeIfPresent([UserInterestDetail].self, forKey: .interests) ?? []
    }
}

/// Partial update body for `PATCH /me/profile`. Optionals that are `nil` are
/// omitted by the synthesized `encode` (`encodeIfPresent`), giving true PATCH
/// semantics — only set fields are written server-side.
nonisolated struct UserProfileUpdate: Codable {
    var firstName: String?
    var lastName: String?
    var dateOfBirth: Date?
    var occupation: String?
    var goalText: String?
    var bio: String?
    var instagram: String?
    var keySkills: String?
    /// Public CDN URL of the uploaded profile image. Set after a successful
    /// R2 presigned upload; `nil` means no change to the stored URL.
    var profileImageUrl: String?
    /// Backend row id of the user's location, resolved via `POST /locations`
    /// before the PATCH. `nil` means no change.
    var locationId: Int?
    /// Replacement interest set (category ids). `nil` leaves interests untouched;
    /// a value (including `[]`) replaces the whole set in the same PATCH.
    var interestCategoryIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case occupation
        case goalText = "goal_text"
        case bio
        case instagram
        case keySkills = "key_skills"
        case profileImageUrl = "profile_image_url"
        case locationId = "location_id"
        case interestCategoryIds = "interest_category_ids"
    }
}

/// A user's interest joined with its category name, embedded in the profile.
/// Interests and program categories are one taxonomy.
nonisolated struct UserInterestDetail: Codable, Identifiable {
    let categoryId: Int
    let categoryName: String

    var id: Int { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
    }
}
