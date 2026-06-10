import Foundation
import Observation

/// The signed-in user's editable profile, backed by the API's `/me/profile`
/// and `/me/interests` endpoints. The view binds directly to these fields;
/// `load()` hydrates them from the backend and `save()` persists edits.
@MainActor
@Observable
final class UserProfileStore {
    /// The signed-in user's row id. Hydrated from `GET /me/profile` on load.
    /// `nil` until the first successful fetch; views that need host-only gating
    /// should compare against this and fall back to "non-host" when nil.
    var currentUserId: Int?
    var displayName: String = ""
    var dateOfBirth: Date?
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

    /// Snapshot captured at load time so the view can tell whether anything has
    /// actually changed and decide whether to enable the Save button.
    private(set) var snapshot: Snapshot?

    struct Snapshot: Equatable {
        var displayName: String
        var dateOfBirth: Date?
        var city: String
        var instagram: String
        var aboutMe: String
        var personalGoal: String
        var occupation: String
        var keySkills: String
        var interestNames: [String]
        var profileImageURL: String?
    }

    /// `true` when any user-editable field differs from the loaded snapshot (or
    /// when a new image has been picked). Drives the Save / Cancel button state
    /// on MyPage.
    var isDirty: Bool {
        if profileImageData != nil { return true }
        guard let snap = snapshot else { return false }
        return snap != currentSnapshot()
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(
            displayName: displayName,
            dateOfBirth: dateOfBirth,
            city: city,
            instagram: instagram,
            aboutMe: aboutMe,
            personalGoal: personalGoal,
            occupation: occupation,
            keySkills: keySkills,
            interestNames: interests.map(\.name),
            profileImageURL: profileImageURL
        )
    }

    /// Revert all edits back to the values captured in the last snapshot.
    /// Called by MyPage's Cancel button.
    func revertToSnapshot() {
        guard let snap = snapshot else { return }
        displayName = snap.displayName
        dateOfBirth = snap.dateOfBirth
        city = snap.city
        instagram = snap.instagram
        aboutMe = snap.aboutMe
        personalGoal = snap.personalGoal
        occupation = snap.occupation
        keySkills = snap.keySkills
        profileImageURL = snap.profileImageURL
        profileImageData = nil
        // Restore interests by name; emoji are presentation-only.
        interests = snap.interestNames.map { name in
            Interest(emoji: Self.emoji(for: name), name: name)
        }
    }

    private let service: ProfileService

    init(service: ProfileService = .shared) {
        self.service = service
    }

    // MARK: - Local persistence
    //
    // The backend may not always have a `user_profiles` row for the signed-in
    // user (older signup flows skipped the auto-create), so server PATCH/GET
    // can 404. To keep the UI usable, every successful save also writes a
    // mirror copy to disk; on load, we fall back to that copy when the
    // server has nothing yet. The picked image is stored alongside as a file
    // in Documents so it survives relaunch.

    private enum LocalKeys {
        static let profile = "user_profile_local_v1"
    }

    private struct LocalProfile: Codable {
        var displayName: String
        var dateOfBirth: Date?
        var city: String
        var instagram: String
        var aboutMe: String
        var personalGoal: String
        var occupation: String
        var keySkills: String
        var profileImageURL: String?
        var interestNames: [String]
    }

    private static var imageFileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("profile_image.dat")
    }

    /// Mirror the current field values to UserDefaults + disk. Called after a
    /// successful save and also when the server 404s so the user's data
    /// survives an app relaunch even without a backend row.
    private func persistLocally() {
        let local = LocalProfile(
            displayName: displayName,
            dateOfBirth: dateOfBirth,
            city: city,
            instagram: instagram,
            aboutMe: aboutMe,
            personalGoal: personalGoal,
            occupation: occupation,
            keySkills: keySkills,
            profileImageURL: profileImageURL,
            interestNames: interests.map(\.name)
        )
        if let data = try? JSONEncoder().encode(local) {
            UserDefaults.standard.set(data, forKey: LocalKeys.profile)
        }
        if let url = Self.imageFileURL {
            if let imageData = profileImageData {
                try? imageData.write(to: url)
            }
            // Don't delete on nil — the user may have an uploaded URL with no
            // pending local data, and we still want the previous picked image
            // available for offline fallback.
        }
    }

    /// Restore field values from local storage, used when the server returns
    /// 404 (no profile row) so the user sees their previously-saved data.
    private func loadLocally() {
        if let data = UserDefaults.standard.data(forKey: LocalKeys.profile),
           let local = try? JSONDecoder().decode(LocalProfile.self, from: data) {
            displayName = local.displayName
            dateOfBirth = local.dateOfBirth
            city = local.city
            instagram = local.instagram
            aboutMe = local.aboutMe
            personalGoal = local.personalGoal
            occupation = local.occupation
            keySkills = local.keySkills
            profileImageURL = local.profileImageURL
            interests = local.interestNames.map { name in
                Interest(emoji: Self.emoji(for: name), name: name)
            }
        }
        if let url = Self.imageFileURL, let data = try? Data(contentsOf: url) {
            profileImageData = data
        }
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
        ("🧒", "Children & Youth"),
        ("🏥", "Health"),
        ("🧠", "Mental Health"),
        ("♿️", "Disability Support"),
        ("🏠", "Homelessness"),
        ("📖", "Literacy"),
        ("🚨", "Disaster Relief"),
        ("⚽️", "Sports"),
        ("🎵", "Music"),
        ("🤝", "Refugees"),
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
        defer {
            isLoading = false
            // Always capture a snapshot — even if the fetch failed — so the
            // view's `isDirty` check has something to diff against and the
            // Save button can light up as soon as the user types.
            if snapshot == nil { snapshot = currentSnapshot() }
        }
        // Profile and interests are fetched independently so a first-time user
        // (who has no profile row yet — backend returns 404) still ends up with
        // a usable form. When the server has nothing we hydrate from the
        // on-device mirror written by `save()`.
        var serverHadProfile = false
        do {
            apply(try await service.fetchMyProfile())
            serverHadProfile = true
        } catch where Self.isCancellation(error) {
            return
        } catch where Self.isNotFound(error) {
            // No profile yet — fall through to local fallback below.
        } catch {
            errorMessage = "Couldn't load your profile. \(Self.message(error))"
        }

        do {
            let details = try await service.fetchMyInterests()
            interests = details.map {
                Interest(emoji: Self.emoji(for: $0.keywordName), name: $0.keywordName)
            }
        } catch where Self.isCancellation(error) {
            return
        } catch where Self.isNotFound(error) {
            // No interests picked yet — empty list is fine.
        } catch {
            // Non-fatal: keep whatever the user has and let them retry on save.
        }

        if !serverHadProfile {
            loadLocally()
        }

        snapshot = currentSnapshot()
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
            try await service.updateMyProfile(update)
            // Interest sync is best-effort — failures here shouldn't block the
            // profile save from being reported as successful.
            _ = try? await service.replaceMyInterests(keywordIds: resolveInterestIds())
            persistLocally()
            snapshot = currentSnapshot()
            return true
        } catch where Self.isNotFound(error) {
            // The backend has no row for this user (older signup flow). Fall
            // back to the on-device mirror so the user still sees their work
            // persist across relaunches.
            persistLocally()
            snapshot = currentSnapshot()
            return true
        } catch {
            errorMessage = "Couldn't save your changes. \(Self.message(error))"
            return false
        }
    }

    // MARK: - Mapping

    private func apply(_ profile: UserProfile) {
        currentUserId = profile.userId
        displayName = [profile.firstName, profile.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        dateOfBirth = profile.dateOfBirth
        profileImageURL = profile.profileImageURL
        instagram = profile.instagram ?? ""
        aboutMe = profile.bio ?? ""
        personalGoal = profile.goalText ?? ""
        occupation = profile.occupation ?? ""
        keySkills = profile.keySkills ?? ""
    }

    private func buildUpdate() -> UserProfileUpdate {
        var update = UserProfileUpdate(
            dateOfBirth: dateOfBirth,
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

    /// HTTP 404 from the backend — typically "no profile row yet" for a brand
    /// new user. Treated as empty state rather than an error.
    private static func isNotFound(_ error: Error) -> Bool {
        if case APIError.serverError(404) = error { return true }
        return false
    }
}
