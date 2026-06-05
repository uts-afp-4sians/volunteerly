import Foundation
import Observation

/// In-memory snapshot of the signed-in user's profile, shared between the
/// signup flow and the profile settings screen. Persisted to disk would be
/// a future step (currently rebuilt from the signup form on each launch).
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
}
