import Foundation
import Observation

/// The three segments of the My Programs screen, mirroring a volunteer's
/// relationship to a program.
enum MyProgramsTab: String, CaseIterable, Identifiable {
    /// Joined programs that haven't finished yet.
    case active = "Active"
    /// Programs that have already taken place (or were closed/cancelled).
    case past = "Past"
    /// Programs the volunteer has requested to join but isn't confirmed for.
    case requested = "Requested"

    var id: String { rawValue }
}

@MainActor
@Observable
final class MyProgramsViewModel {
    var programs: [Program] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedTab: MyProgramsTab = .active

    /// Programs the volunteer has pinned to the top of the list. Seeded so the
    /// screen demonstrates the pinned state out of the box.
    var pinnedProgramIds: Set<Int> = [1, 2]
    /// "Filter" affordance: when on, only pinned programs are shown.
    var pinnedOnly = false

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = MockHTTPClient.shared) {
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            programs = try await httpClient.get("/programs")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Pinning

    func isPinned(_ program: Program) -> Bool {
        pinnedProgramIds.contains(program.id)
    }

    func togglePin(_ program: Program) {
        if pinnedProgramIds.contains(program.id) {
            pinnedProgramIds.remove(program.id)
        } else {
            pinnedProgramIds.insert(program.id)
        }
    }

    // MARK: - Filtering

    /// Programs for the current tab, after search/pin filters, pinned first.
    var visiblePrograms: [Program] {
        let now = Date.now
        var list = programs.filter { belongs($0, to: selectedTab, now: now) }

        if !searchQuery.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery)
                    || $0.description.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        if pinnedOnly {
            list = list.filter(isPinned)
        }

        return list.sorted { lhs, rhs in
            let lPinned = isPinned(lhs), rPinned = isPinned(rhs)
            if lPinned != rPinned { return lPinned }       // pinned first
            return lhs.startDatetime < rhs.startDatetime    // then soonest
        }
    }

    private func belongs(_ program: Program, to tab: MyProgramsTab, now: Date) -> Bool {
        switch tab {
        case .active:
            return program.endDatetime >= now && (program.status == .open || program.status == .full)
        case .past:
            return program.endDatetime < now || program.status == .closed || program.status == .cancelled
        case .requested:
            return program.status == .draft
        }
    }
}
