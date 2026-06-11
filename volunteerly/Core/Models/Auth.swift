import Foundation

enum AuthValidation {
    static let minimumPasswordLength = 8

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
