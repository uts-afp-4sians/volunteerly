import Foundation

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
