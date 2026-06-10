import Foundation

/// On-device cache of the signed-in user's profile.
///
/// The profile carries its interests, so one cached object hydrates the whole
/// My Page instantly on launch — no spinner, no blank form. It's written only
/// when the profile is (re)loaded or saved, and cleared on logout / account
/// deletion, matching the "refresh only on edit/logout/withdraw" policy.
enum ProfileCache {
    private static let key = "cached_my_profile_v1"

    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(UserProfile.self, from: data)
    }

    static func save(_ profile: UserProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
