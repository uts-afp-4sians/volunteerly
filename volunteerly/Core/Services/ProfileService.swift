import Foundation

/// Talks to the backend's `/me/profile` endpoint for the signed-in user.
/// Interests are embedded in that one resource (read) and replaced through the
/// same `PATCH` (write), so there's no separate interests round-trip. Uses the
/// shared `HTTPClient`, so the bearer token attached by `AuthService` rides
/// along automatically.
final class ProfileService {
    static let shared = ProfileService(client: LiveHTTPClient.shared)

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: Profile (interests embedded)

    func fetchMyProfile() async throws -> UserProfile {
        try await client.get("/me/profile")
    }

    @discardableResult
    func updateMyProfile(_ update: UserProfileUpdate) async throws -> UserProfile {
        try await client.patch("/me/profile", body: update)
    }

    // MARK: Locations

    /// Find-or-create a backend location row for a place picked on the map (or
    /// geocoded from typed text); the returned id goes into the profile PATCH.
    func createLocation(_ request: LocationCreateRequest) async throws -> Location {
        try await client.post("/locations", body: request)
    }

    // MARK: Catalogues

    /// The full keyword catalogue, used to resolve interest names → ids on save.
    func fetchKeywordCatalog() async throws -> [Keyword] {
        try await client.get("/keywords")
    }

    /// The profile-interest catalogue — the chips offered on the signup
    /// interests step and the "My interests" picker. Backed by `/interests`,
    /// the subset of keywords flagged `is_interest` in the DB.
    func fetchInterestCatalog() async throws -> [Keyword] {
        try await client.get("/interests")
    }
}
