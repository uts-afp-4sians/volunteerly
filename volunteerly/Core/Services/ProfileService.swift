import Foundation

/// Talks to the backend's `/me/profile` and `/me/interests` endpoints for the
/// signed-in user. Uses the shared `HTTPClient`, so the bearer token attached by
/// `AuthService` rides along automatically.
final class ProfileService {
    static let shared = ProfileService(client: LiveHTTPClient.shared)

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: Profile

    func fetchMyProfile() async throws -> UserProfile {
        try await client.get("/me/profile")
    }

    @discardableResult
    func updateMyProfile(_ update: UserProfileUpdate) async throws -> UserProfile {
        try await client.patch("/me/profile", body: update)
    }

    // MARK: Interests

    func fetchMyInterests() async throws -> [UserInterestDetail] {
        try await client.get("/me/interests")
    }

    /// The full keyword catalogue, used to resolve interest names → ids on save.
    func fetchKeywordCatalog() async throws -> [Keyword] {
        try await client.get("/keywords")
    }

    @discardableResult
    func replaceMyInterests(keywordIds: [Int]) async throws -> [UserInterestDetail] {
        try await client.put("/me/interests", body: UserInterestsUpdate(keywordIds: keywordIds))
    }
}
