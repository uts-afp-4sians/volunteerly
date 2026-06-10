import Foundation
import Observation

/// The set of programs the signed-in user has joined, mirrored on-device.
///
/// The backend exposes per-program participation (`GET /programs/{id}/participations`)
/// but no "list my programs" endpoint, so the iOS client keeps its own
/// persistent set of joined ids. It's updated from two places:
/// 1. `ProgramDetailViewModel.toggleJoin()` — direct join/leave actions.
/// 2. The same view model's load path — whenever the server reports a
///    program as joined (or not), the store is reconciled to match.
///
/// MyPage reads this set to filter its "My Programs" list.
@MainActor
@Observable
final class JoinedProgramsStore {
    static let shared = JoinedProgramsStore()

    private(set) var ids: Set<Int>

    private static let key = "joined_program_ids_v1"

    private init() {
        let stored = UserDefaults.standard.array(forKey: Self.key) as? [Int] ?? []
        ids = Set(stored)
    }

    func contains(_ id: Int) -> Bool { ids.contains(id) }

    func setJoined(_ joined: Bool, programId: Int) {
        let didChange: Bool
        if joined {
            didChange = ids.insert(programId).inserted
        } else {
            didChange = ids.remove(programId) != nil
        }
        if didChange { persist() }
    }

    private func persist() {
        UserDefaults.standard.set(Array(ids), forKey: Self.key)
    }
}
