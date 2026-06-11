import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class ProgramListViewModel {
    var programs: [Program] = []
    var categories: [ProgramCategory] = []
    var isLoading = false
    var isLoadingCategories = false
    var errorMessage: String?
    var searchQuery = ""
    var selectedCategoryId: Int?

    /// Category ids the user said they care about during signup. Programs
    /// matching these surface above unmatched programs in `filteredPrograms`.
    var preferredCategoryIds: Set<Int> = []

    /// Translates the signup-form interest names to the category names that
    /// actually exist in the catalog.
    private static let interestToCategoryName: [String: String] = [
        "Animal Care": "Animals",
        "Arts & Creativity": "Arts",
        "Community Building": "Community",
        "Education": "Education",
        "Aged Care": "Seniors",
        "Elder Care": "Seniors",
        "Environment": "Environment",
        "Food": "Food",
    ]

    // MARK: - Filters (the "Confirm details" bottom sheet)

    /// Bounds for the distance slider. Distance has no per-program data yet, so
    /// it round-trips to the server as a reserved control but doesn't narrow
    /// results — kept here so the slider has a home.
    let distanceRange: ClosedRange<Double> = 0...50    // km
    var maxDistance: Double = 50

    /// Team-size buckets (mapped to `maxVolunteers` server-side and on the mock).
    var selectedTeamSizes: Set<TeamSize> = []
    var selectedFrequencies: Set<CommitmentFrequency> = []
    var selectedDurations: Set<CommitmentDuration> = []

    /// Whether any bottom-sheet filter is active (drives the button's badge).
    var hasActiveFilters: Bool {
        !selectedTeamSizes.isEmpty
            || !selectedFrequencies.isEmpty
            || !selectedDurations.isEmpty
    }

    /// Client-side mirror of the server filters. The live API already narrows
    /// the payload via query string; re-applying the same predicates here gives
    /// instant feedback before the network returns and lets the mock client
    /// (which ignores the query string) filter for previews.
    var filteredPrograms: [Program] {
        let matched = programs.filter { program in
            let matchesCategory = selectedCategoryId == nil
                || program.categoryId == selectedCategoryId
            let matchesSearch = searchQuery.isEmpty
                || program.name.localizedCaseInsensitiveContains(searchQuery)
                || program.description.localizedCaseInsensitiveContains(searchQuery)
            let matchesTeamSize = selectedTeamSizes.isEmpty
                || selectedTeamSizes.contains { $0.matches(maxVolunteers: program.maxVolunteers) }
            let matchesFrequency = selectedFrequencies.isEmpty
                || (program.commitmentFrequency.map(selectedFrequencies.contains) ?? false)
            let matchesDuration = selectedDurations.isEmpty
                || (program.commitmentDuration.map(selectedDurations.contains) ?? false)
            return matchesCategory && matchesSearch
                && matchesTeamSize && matchesFrequency && matchesDuration
        }
        // Sort interest-matching programs to the top, preserving original
        // order within each bucket. Skip when the user manually picked a chip.
        guard selectedCategoryId == nil, !preferredCategoryIds.isEmpty else { return matched }
        return matched.sorted { lhs, rhs in
            let lhsPreferred = preferredCategoryIds.contains(lhs.categoryId)
            let rhsPreferred = preferredCategoryIds.contains(rhs.categoryId)
            if lhsPreferred == rhsPreferred { return false }
            return lhsPreferred && !rhsPreferred
        }
    }

    private let httpClient: HTTPClient
    private let locationProvider: any LocationProviding

    /// The caller's coordinate, resolved once on first load and sent to the API
    /// so each card can show its distance. `nil` until/unless location is granted.
    private var userCoordinate: CLLocationCoordinate2D?

    /// One-shot guard so the permission prompt is raised at most once; denying
    /// it must not re-prompt on every search/filter reload.
    private var didAttemptLocation = false

    /// Background coordinate-resolution task. Exposed (internal) so tests can
    /// await the silent distance re-fetch it triggers.
    private(set) var locationTask: Task<Void, Never>?

    init(
        httpClient: HTTPClient = LiveHTTPClient.shared,
        locationProvider: (any LocationProviding)? = nil
    ) {
        self.httpClient = httpClient
        // Resolve the MainActor-isolated singleton here in the actor-isolated
        // init body — a `= .shared` default argument is evaluated nonisolated
        // and is an error under the Swift 6 language mode.
        self.locationProvider = locationProvider ?? LocationProvider.shared
    }

    /// Builds `/programs` with the current filters as query items. Repeated
    /// params (team_size, commitment_frequency, commitment_duration) are OR-ed
    /// within a group and AND-ed across groups by the API.
    private var programsPath: String {
        var items: [URLQueryItem] = []
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { items.append(.init(name: "q", value: trimmed)) }
        if let categoryId = selectedCategoryId {
            items.append(.init(name: "category_id", value: String(categoryId)))
        }
        items += selectedTeamSizes.map { .init(name: "team_size", value: $0.rawValue) }
        items += selectedFrequencies.map { .init(name: "commitment_frequency", value: $0.rawValue) }
        items += selectedDurations.map { .init(name: "commitment_duration", value: $0.rawValue) }
        if let coordinate = userCoordinate {
            items.append(.init(name: "lat", value: String(coordinate.latitude)))
            items.append(.init(name: "lng", value: String(coordinate.longitude)))
        }

        guard !items.isEmpty else { return "/programs" }
        var components = URLComponents()
        components.queryItems = items
        return "/programs?" + (components.percentEncodedQuery ?? "")
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        await fetchPrograms()
        isLoading = false

        // Distance is supplementary, so the list never waits on it: resolve the
        // coordinate in the background (the permission prompt can sit unanswered
        // forever) and, once it arrives, silently re-fetch so cards gain their
        // "1.5km" labels — no spinner, no blocked list.
        resolveLocationIfNeeded()
    }

    /// Fetches programs with the current filters and `userCoordinate`. Records a
    /// failure in `errorMessage` and otherwise clears it; the existing list is
    /// left untouched on error.
    private func fetchPrograms() async {
        do {
            self.programs = try await httpClient.get(programsPath)
            self.errorMessage = nil
        } catch where error.isCancellation {
            // Fetch cancelled by a tab switch / superseding filter change —
            // leave the existing list and don't flash an error.
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Loads the category catalog on its own track. Categories are a separate
    /// resource from the program list and only need fetching once, so a category
    /// outage must not blank the list, and the list reloading on every
    /// search/filter must not refetch them. Failure leaves the row empty rather
    /// than surfacing a blocking error over the (still usable) program list.
    func loadCategories() async {
        guard categories.isEmpty else { return }
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        categories = (try? await httpClient.get("/categories")) ?? []
    }

    /// Resolves the device coordinate at most once and, on success, re-fetches
    /// so distances appear. Fire-and-forget: `load()` returns immediately even
    /// when the permission prompt is never answered.
    private func resolveLocationIfNeeded() {
        guard !didAttemptLocation else { return }
        didAttemptLocation = true
        locationTask = Task { [weak self] in
            guard let self else { return }
            guard let coordinate = await self.locationProvider.currentCoordinate() else { return }
            guard !Task.isCancelled else { return }
            self.userCoordinate = coordinate
            await self.fetchPrograms()
        }
    }

    func toggleCategory(_ id: Int) {
        selectedCategoryId = (selectedCategoryId == id) ? nil : id
    }

    /// Resolve the user's chosen interest names against the loaded categories
    /// and remember their ids so `filteredPrograms` can surface them first.
    func applyUserInterests(_ interestNames: [String]) {
        guard !categories.isEmpty else {
            preferredCategoryIds = []
            return
        }
        let categoryNames = Set(interestNames.map {
            Self.interestToCategoryName[$0] ?? $0
        })
        preferredCategoryIds = Set(
            categories.filter { categoryNames.contains($0.name) }.map(\.id)
        )
    }

    /// Clears every bottom-sheet filter (distance is left at its max = no cap).
    func resetFilters() {
        selectedTeamSizes.removeAll()
        selectedFrequencies.removeAll()
        selectedDurations.removeAll()
        maxDistance = distanceRange.upperBound
    }
}
