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
    let commitmentFrequency: CommitmentFrequency?
    let commitmentDuration: CommitmentDuration?
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
        case commitmentFrequency = "commitment_frequency"
        case commitmentDuration = "commitment_duration"
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
    var commitmentFrequency: CommitmentFrequency? = nil
    var commitmentDuration: CommitmentDuration? = nil
    var bannerImageURL: String? = nil
    var locationId: Int? = nil

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case programName = "program_name"
        case description
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case maxVolunteers = "max_volunteers"
        case commitmentFrequency = "commitment_frequency"
        case commitmentDuration = "commitment_duration"
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

/// How often a program expects volunteers to show up. Wire values match the
/// API `CommitmentFrequency` enum.
nonisolated enum CommitmentFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:  "Weekly"
        case .monthly: "Monthly"
        }
    }
}

/// Expected length of commitment, as filter buckets (months). Wire values match
/// the API `CommitmentDuration` enum.
nonisolated enum CommitmentDuration: String, Codable, CaseIterable, Identifiable {
    case under2 = "under_2"
    case threeToSix = "three_to_six"
    case sevenToNine = "seven_to_nine"
    case continuous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under2:      "<2"
        case .threeToSix:  "3 to 6"
        case .sevenToNine: "7 to 9"
        case .continuous:  "Continuous"
        }
    }
}

/// Team-size preference buckets. Not stored on a program — derived from
/// `maxVolunteers`. Wire values match the API `TeamSize` query enum.
nonisolated enum TeamSize: String, Codable, CaseIterable, Identifiable {
    case small   // 2-3
    case medium  // 4-6
    case large   // 7-10
    case open    // 11+

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:  "2-3"
        case .medium: "4-6"
        case .large:  "7-10"
        case .open:   "Open"
        }
    }

    /// Whether a program with `maxVolunteers` capacity falls in this bucket.
    func matches(maxVolunteers: Int) -> Bool {
        switch self {
        case .small:  (2...3).contains(maxVolunteers)
        case .medium: (4...6).contains(maxVolunteers)
        case .large:  (7...10).contains(maxVolunteers)
        case .open:   maxVolunteers >= 11
        }
    }
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
