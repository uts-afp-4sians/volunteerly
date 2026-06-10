import Foundation
import Observation

/// The signed-in user's editable profile, backed by the API's `/me/profile`
/// endpoint (interests embedded). The view binds directly to these fields;
/// `load()` hydrates them — instantly from the on-device cache, then silently
/// revalidating against the backend — and `save()` persists edits.
@MainActor
@Observable
final class UserProfileStore {
    var displayName: String = ""
    var city: String = ""
    var instagram: String = ""
    var aboutMe: String = ""
    var personalGoal: String = ""
    var occupation: String = ""
    var keySkills: String = ""
    var profileImageData: Data?
    /// Public CDN URL of the saved profile image (hydrated from the backend).
    /// `profileImageData` takes precedence when the user has just picked a new one.
    var profileImageURL: String?
    var interests: [Interest] = []

    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    /// `true` once the fields hold real data (from cache or network). Drives the
    /// My Page loading state: a spinner shows only while loading with nothing
    /// cached yet — a returning user never sees it.
    var isHydrated = false

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

    /// Hydrate every field — instantly from the cache, then revalidating against
    /// the backend. A single `/me/profile` read carries the interests too. Safe
    /// to call on each appearance; surfaces failures via `errorMessage` only
    /// when there's no cache to fall back on.
    func load() async {
        // Cache-first: render the last-saved snapshot immediately so a returning
        // user sees their profile with no spinner or blank flash.
        if !isHydrated, let cached = ProfileCache.load() {
            apply(cached)
            isHydrated = true
        }

        // Revalidate in the background (single call — interests are embedded).
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let profile = try await service.fetchMyProfile()
            apply(profile)
            isHydrated = true
            ProfileCache.save(profile)
        } catch where Self.isCancellation(error) {
            return
        } catch {
            // With a cached profile already on screen, fail silently and stay on
            // it; only surface the error when there's nothing to show.
            if !isHydrated {
                errorMessage = "Couldn't load your profile. \(Self.message(error))"
            }
        }
    }

    /// Discard unsaved edits by re-applying the cached (last-saved) profile.
    /// Offline-safe — no network needed.
    func revertToCache() {
        if let cached = ProfileCache.load() {
            apply(cached)
        }
    }

    /// Persist the current field values: a `PATCH` for the scalar profile and a
    /// `PUT` to replace the interest set. Returns `true` on success.
    ///
    /// If `profileImageData` is set, the image is uploaded to R2 first via
    /// `UploadService` and the returned CDN URL is embedded in the PATCH body.
    /// On upload failure the method surfaces the error and returns early so the
    /// rest of the profile is not patched with a stale or missing image URL.
    @discardableResult
    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        var update = buildUpdate()

        // Upload profile image when the user has picked a new one.
        if let imageData = profileImageData {
            do {
                let publicURL = try await UploadService.upload(
                    data: imageData,
                    kind: .profile_image
                )
                // publicURL is nil only in local-dev with no R2 bucket — skip the
                // field so the server keeps whatever URL it already has.
                if let url = publicURL {
                    update.profileImageUrl = url
                    // Point the avatar at the freshly uploaded CDN image and drop
                    // the now-consumed local picker data so it renders the remote URL.
                    profileImageURL = url
                    profileImageData = nil
                }
                // When there's no R2 bucket we keep `profileImageData` so the picked
                // image still previews for the rest of the session.
            } catch {
                errorMessage = "Couldn't upload profile image. \(Self.message(error))"
                return false
            }
        }

        do {
            // Fold the interest replacement into the same PATCH — one round-trip.
            update.interestKeywordIds = try await resolveInterestIds()
            let saved = try await service.updateMyProfile(update)
            // The server is the source of truth post-save: re-hydrate from its
            // response and refresh the cache so the next launch is instant.
            apply(saved)
            isHydrated = true
            ProfileCache.save(saved)
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
        profileImageURL = profile.profileImageURL
        instagram = profile.instagram ?? ""
        aboutMe = profile.bio ?? ""
        personalGoal = profile.goalText ?? ""
        occupation = profile.occupation ?? ""
        keySkills = profile.keySkills ?? ""
        interests = profile.interests.map {
            Interest(emoji: Self.emoji(for: $0.keywordName), name: $0.keywordName)
        }
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

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let error = error as NSError
        return error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled
    }
}
