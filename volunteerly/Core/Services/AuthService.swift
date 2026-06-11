import Foundation

/// Centralizes authentication against the backend.
///
/// On a successful login/register the returned JWT is persisted in
/// `SessionManager` and attached to `LiveHTTPClient` so every subsequent
/// authenticated request carries the `Authorization: Bearer` header.
final class AuthService {
    static let shared = AuthService(client: LiveHTTPClient.shared)

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    @discardableResult
    func login(email: String, password: String) async throws -> AuthResponse {
        let response: AuthResponse = try await client.post(
            "/auth/login",
            body: LoginRequest(email: email, password: password)
        )
        persist(response)
        return response
    }

    @discardableResult
    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthResponse {
        let response: AuthResponse = try await client.post(
            "/auth/register",
            body: RegisterRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
        )
        persist(response)
        return response
    }

    /// Change the signed-in user's password. The backend verifies
    /// `currentPassword` and returns `204` on success or `401` when it's wrong
    /// (surfaced as `APIError.unauthorized`).
    func changePassword(currentPassword: String, newPassword: String) async throws {
        try await client.postExpectingNoContent(
            "/auth/change-password",
            body: ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
        )
    }

    func logout() {
        SessionManager.shared.clearSession()
        LiveHTTPClient.shared.authToken = nil
        // Drop the cached profile so the next user doesn't briefly see this one.
        ProfileCache.clear()
    }

    /// Re-attach a persisted token to the live client. Call once at launch so a
    /// returning user's authenticated requests work before any login.
    func restoreSession() {
        LiveHTTPClient.shared.authToken = SessionManager.shared.token
    }

    private func persist(_ response: AuthResponse) {
        SessionManager.shared.token = response.token
        LiveHTTPClient.shared.authToken = response.token
    }
}
