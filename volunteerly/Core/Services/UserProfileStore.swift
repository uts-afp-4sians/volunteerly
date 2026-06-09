import Foundation
import Observation

/// The signed-in user's editable profile, backed by the API's `/me/profile`
/// and `/me/interests` endpoints. The view binds directly to these fields;
/// `load()` hydrates them from the backend and `save()` persists edits.
@MainActor
@Observable
final class UserProfileStore {
    var displayName: String = ""
    var instagram: String = ""
    var aboutMe: String = ""
    var personalGoal: String = ""
    var occupation: String = ""
    var keySkills: String = ""
    var profileImageData: Data?
    var interests: [Interest] = []

    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let service: ProfileService

    init(service: ProfileService = .shared) {
        self.service = service
    }

    struct Interest: Identifiable, Hashable {
        let id: UUID
        var emoji: String
        var name: String

        init(id: UUID = UUID(), emoji: String, name: String) {
            self.id = id
            self.emoji = emoji
            self.name = name
        }
    }

    // MARK: - Interest catalogue

    /// The fixed set of interests the picker offers, mirroring the seeded
    /// keyword catalogue (`scripts/seed.py`). Emoji are presentation-only — the
    /// backend stores just the keyword name — so they live here on the client.
    static let interestCatalog: [(emoji: String, name: String)] = [
        ("🐶", "Animal Care"),
        ("🎨", "Arts & Creativity"),
        ("👥", "Community Building"),
        ("📚", "Education"),
        ("🧓", "Aged Care"),
        ("🌱", "Environment"),
        ("🍽️", "Food"),
        ("✊", "Social Justice"),
        ("💻", "Technology"),
    ]

    /// Emoji for a keyword name, defaulting to a generic tag for anything not in
    /// the catalogue.
    static func emoji(for name: String) -> String {
        interestCatalog.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.emoji ?? "🏷️"
    }

    // MARK: - Backend sync

    /// Hydrate every field from the backend. Safe to call on each appearance;
    /// surfaces failures via `errorMessage` rather than throwing.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let profile = service.fetchMyProfile()
            async let interestDetails = service.fetchMyInterests()
            apply(try await profile)
            interests = try await interestDetails.map {
                Interest(emoji: Self.emoji(for: $0.keywordName), name: $0.keywordName)
            }
        } catch {
            errorMessage = "Couldn't load your profile. \(Self.message(error))"
        }
    }

    /// Persist the current field values: a `PATCH` for the scalar profile and a
    /// `PUT` to replace the interest set. Returns `true` on success.
    @discardableResult
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await service.updateMyProfile(buildUpdate())
            try await service.replaceMyInterests(keywordIds: resolveInterestIds())
            return true
        } catch {
            errorMessage = "Couldn't save your changes. \(Self.message(error))"
            return false
        }
    }

    // MARK: - Mapping

    private func apply(_ profile: UserProfile) {
        displayName = [profile.firstName, profile.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        instagram = profile.instagram ?? ""
        aboutMe = profile.bio ?? ""
        personalGoal = profile.goalText ?? ""
        occupation = profile.occupation ?? ""
        keySkills = profile.keySkills ?? ""
    }

    private func buildUpdate() -> UserProfileUpdate {
        var update = UserProfileUpdate(
            occupation: occupation,
            goalText: personalGoal,
            bio: aboutMe,
            instagram: instagram.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")),
            keySkills: keySkills
        )
        // Split the single display name into first/last. The backend requires a
        // non-empty first name, so only send names when the field has content.
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            update.firstName = parts[0]
            update.lastName = parts.count > 1 ? parts[1] : ""
        }
        return update
    }

    /// Resolve the selected interest names to seeded keyword ids via the
    /// catalogue. Names without a matching keyword can't be persisted and are
    /// dropped (the picker only offers catalogue interests, so this is rare).
    private func resolveInterestIds() async throws -> [Int] {
        let catalog = try await service.fetchKeywordCatalog()
        let byName = Dictionary(
            catalog.map { ($0.name.lowercased(), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
        return interests.compactMap { byName[$0.name.lowercased()] }
    }

    private static func message(_ error: Error) -> String {
        (error as? APIError)?.errorDescription ?? error.localizedDescription
    }
}
