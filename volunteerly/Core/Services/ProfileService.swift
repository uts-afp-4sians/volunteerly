import Foundation

/// Talks to the backend's `/me/profile` endpoint for the signed-in user.
/// Interests are embedded in that one resource (read) and replaced through the
/// same `PATCH` (write), so there's no separate interests round-trip. Uses the
/// shared `HTTPClient`, so the bearer token attached by `AuthService` rides
/// along automatically.
final class ProfileService {
    static let shared = ProfileService(client: LiveHTTPClient.shared)

    /// Exposed (not private) so MainActor callers can hand the same client to
    /// `CategoryStore` for the cached interest/category catalog.
    let client: HTTPClient

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

    // The interest catalog is the category catalog (one taxonomy) — callers
    // read it through `CategoryStore`, which caches `/categories` for an hour.
}
