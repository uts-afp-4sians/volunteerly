import Foundation
import Observation

@MainActor
@Observable
final class ProgramDetailViewModel {
    let programId: Int

    var program: Program?
    var host: UserProfile?
    var location: Location?
    var category: ProgramCategory?
    var similarProgram: Program?
    /// Straight-line distance to `similarProgram`, in kilometres, when both
    /// programs have located coordinates. `nil` when picked by city/category.
    var similarDistanceKm: Double?
    var isLoading = false
    var errorMessage: String?

    var isBookmarked = false
    var isJoined = false

    /// Live participation snapshot from `GET /programs/{id}/participations`.
    var participantCount = 0
    var isFull = false
    /// In-flight guard so a double-tap can't fire two join/leave requests.
    var isJoining = false

    /// Whether the Join button should be tappable: not already in flight, and
    /// either the caller has joined (so they can leave) or a slot is free.
    var canToggleJoin: Bool { !isJoining && (isJoined || !isFull) }

    /// Members other than the host, used to drive the avatar row.
    var otherMemberCount: Int { Swift.max(0, participantCount - 1) }

    private var participationsPath: String { "/programs/\(programId)/participations" }

    private let httpClient: HTTPClient

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.programId = programId
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let program: Program = try await httpClient.get("/programs/\(programId)")
            self.program = program
            // The Join counter is carried by the program resource itself.
            participantCount = program.participantCount ?? 0
            isFull = program.isFull ?? false

            // Host and location are supplementary — a missing one shouldn't fail the screen.
            async let host: UserProfile = httpClient.get("/users/\(program.creatorUserId)/profile")
            async let location: Location = httpClient.get("/locations/\(program.locationId)")
            async let categories: [ProgramCategory] = httpClient.get("/categories")
            // One server-side suggestion (bounded LIMIT 1) instead of pulling
            // whole tables to rank client-side.
            async let similar: SimilarProgram = httpClient.get("/programs/\(programId)/similar")
            // `joined` is per-user, so it stays an authed lookup on the
            // participation sub-resource (the counter already came with detail).
            async let participation: ProgramParticipationSummary = httpClient.get(participationsPath)
            self.host = try? await host
            self.location = try? await location
            self.category = (try? await categories)?.first { $0.id == program.categoryId }

            if let similar = try? await similar {
                self.similarProgram = similar.program
                self.similarDistanceKm = similar.distanceKm
            }

            // Participation is supplementary — failing to load it shouldn't
            // blank the screen; we just keep the detail-sourced counter.
            if let summary = try? await participation {
                apply(summary)
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func apply(_ summary: ProgramParticipationSummary) {
        participantCount = summary.participantCount
        isFull = summary.isFull
        isJoined = summary.joined
    }

    func toggleBookmark() { isBookmarked.toggle() }

    /// Join when there's a free slot, or leave when already joined. Returns
    /// `true` when a join just succeeded so the view can show the confirmation.
    @discardableResult
    func toggleJoin() async -> Bool {
        guard canToggleJoin else { return false }
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }

        do {
            if isJoined {
                try await httpClient.delete(participationsPath)
                participantCount = Swift.max(0, participantCount - 1)
                isFull = false
                isJoined = false
                return false
            } else {
                let summary: ProgramParticipationSummary = try await httpClient.post(
                    participationsPath, body: EmptyBody()
                )
                apply(summary)
                return summary.joined
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Empty JSON body for POSTs whose inputs come entirely from the path + auth token.
private struct EmptyBody: Encodable {}

/// Response of `GET /programs/{id}/similar`: one suggested program plus its
/// distance (km) when the match was made by coordinates.
struct SimilarProgram: Decodable {
    let program: Program
    let distanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case program
        case distanceKm = "distance_km"
    }
}
