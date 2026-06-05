import Foundation

nonisolated struct Program: Identifiable, Codable {
    let id: Int
    let creatorUserId: Int
    let categoryId: Int
    let locationId: Int
    let name: String
    let description: String
    let bannerImageURL: String?
    let startDatetime: Date
    let endDatetime: Date
    let maxVolunteers: Int
    let status: ProgramStatus
    let isDeleted: Bool
    let deletedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "program_id"
        case creatorUserId = "creator_user_id"
        case categoryId = "category_id"
        case locationId = "location_id"
        case name = "program_name"
        case description
        case bannerImageURL = "banner_image_url"
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case maxVolunteers = "max_volunteers"
        case status
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
    }
}

/// Create payload for `POST /programs`. The creator is derived server-side from
/// the auth token; nil fields are omitted (the server defaults `location_id`).
nonisolated struct ProgramCreateRequest: Encodable {
    let categoryId: Int
    let programName: String
    let description: String
    let startDatetime: Date
    let endDatetime: Date
    let maxVolunteers: Int
    var bannerImageURL: String? = nil
    var locationId: Int? = nil

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case programName = "program_name"
        case description
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case maxVolunteers = "max_volunteers"
        case bannerImageURL = "banner_image_url"
        case locationId = "location_id"
    }
}

nonisolated enum ProgramStatus: String, Codable {
    case draft
    case open
    case full
    case closed
    case cancelled
}

nonisolated struct ProgramParticipation: Identifiable, Codable {
    let id: Int
    let programId: Int
    let userId: Int
    let status: ParticipationStatus
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "participation_id"
        case programId = "program_id"
        case userId = "user_id"
        case status = "participation_status"
        case joinedAt = "joined_at"
    }
}

nonisolated enum ParticipationStatus: String, Codable {
    case pending
    case approved
    case rejected
    case withdrawn
}

nonisolated struct ProgramBookmark: Codable {
    let userId: Int
    let programId: Int
    let bookmarkedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case programId = "program_id"
        case bookmarkedAt = "bookmarked_at"
    }
}

/// Junction tagging a program with a keyword (PROGRAM_KEYWORD).
nonisolated struct ProgramKeyword: Codable {
    let programId: Int
    let keywordId: Int

    enum CodingKeys: String, CodingKey {
        case programId = "program_id"
        case keywordId = "keyword_id"
    }
}
