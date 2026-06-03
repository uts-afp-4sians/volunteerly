import Foundation

final class SessionManager {
    static let shared = SessionManager()

    private let tokenKey = "auth_token"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    var hasSession: Bool { token != nil }

    func clearSession() {
        token = nil
    }
}
