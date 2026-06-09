import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class ProgramListViewModel {
    var programs: [Program] = []
    var categories: [ProgramCategory] = []
    var isLoading = false
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
    private let locationProvider: LocationProvider

    /// The caller's coordinate, resolved once on first load and sent to the API
    /// so each card can show its distance. `nil` until/unless location is granted.
    private var userCoordinate: CLLocationCoordinate2D?

    init(
        httpClient: HTTPClient = LiveHTTPClient.shared,
        locationProvider: LocationProvider = .shared
    ) {
        self.httpClient = httpClient
        self.locationProvider = locationProvider
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

        // Resolve the device location once so the list can carry per-card
        // distances. Best-effort: if it's nil, the cards fall back to dates.
        if userCoordinate == nil {
            userCoordinate = await locationProvider.currentCoordinate()
        }

        do {
            async let programs: [Program] = httpClient.get(programsPath)
            // Categories only need to load once.
            if categories.isEmpty {
                async let categories: [ProgramCategory] = httpClient.get("/categories")
                self.categories = try await categories
            }
            self.programs = try await programs
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
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
