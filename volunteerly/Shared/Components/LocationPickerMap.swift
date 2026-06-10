import SwiftUI
import MapKit
import CoreLocation

/// A location resolved on the picker map — carries both the display string for
/// form fields and the structured parts the backend's `POST /locations`
/// find-or-create expects.
struct PickedLocation: Equatable {
    /// Short human-readable form for text fields, e.g. "Ultimo, NSW".
    var name: String
    var city: String
    var stateRegion: String?
    var country: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Search field + map pair with two-way sync (Figma 329:903 / 329:909):
/// panning or pinching the map reverse-geocodes its centre into the search
/// field, and tapping a search suggestion pins the map on that place. The
/// centre pin always marks the current selection, reported via `picked`.
struct LocationPickerMap: View {
    @Binding var picked: PickedLocation?
    var mapHeight: CGFloat = 249
    /// Pre-fills the search field when there's a saved name but no coordinate
    /// (e.g. returning to a signup step).
    var initialName: String?
    /// Centre on the device's location when nothing is picked yet.
    var centersOnUserLocation = true

    @State private var searchText: String
    @State private var suggestions: [LocationSuggestion] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var reverseTask: Task<Void, Never>?

    @State private var position: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion
    /// Centre of the last camera move *we* made (init, GPS, suggestion tap).
    /// `onMapCameraChange` events landing on it are echoes of our own move, not
    /// a user gesture, and must not be reverse-geocoded back into the field.
    @State private var lastProgrammaticCenter: CLLocationCoordinate2D?
    /// Skips search scheduling for the next `searchText` change when the text
    /// was set by us (reverse geocode / suggestion) rather than typed.
    @State private var suppressNextSearch = false

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), // Sydney
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    init(
        picked: Binding<PickedLocation?>,
        mapHeight: CGFloat = 249,
        initialName: String? = nil,
        centersOnUserLocation: Bool = true
    ) {
        _picked = picked
        self.mapHeight = mapHeight
        self.initialName = initialName
        self.centersOnUserLocation = centersOnUserLocation

        let region: MKCoordinateRegion
        if let existing = picked.wrappedValue {
            region = MKCoordinateRegion(
                center: existing.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            _searchText = State(initialValue: existing.name)
        } else {
            region = Self.defaultRegion
            _searchText = State(initialValue: initialName ?? "")
        }
        _position = State(initialValue: .region(region))
        _visibleRegion = State(initialValue: region)
        _lastProgrammaticCenter = State(initialValue: region.center)
    }

    var body: some View {
        VStack(spacing: 16) {
            searchField
            mapView
                .overlay(alignment: .top) {
                    if !suggestions.isEmpty {
                        suggestionsList
                    }
                }
        }
        .task {
            guard centersOnUserLocation, picked == nil,
                  let coordinate = await LocationProvider.shared.currentCoordinate()
            else { return }
            // Don't fight a pick made while the GPS fix was resolving.
            guard picked == nil else { return }
            moveCamera(to: coordinate)
            reverseGeocode(coordinate)
        }
        .onChange(of: searchText) { _, newValue in
            if suppressNextSearch {
                suppressNextSearch = false
                return
            }
            scheduleSearch(query: newValue)
        }
    }

    // MARK: - Search field (Figma SEARCH-BAR 232:366)

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.placeholder)
            TextField("Search", text: $searchText)
                .font(.bodyText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { runSearch(query: searchText) }
            if isSearching {
                ProgressView()
            } else if !searchText.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.placeholder)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Map (Figma MAP 232:359)

    private var mapView: some View {
        Map(position: $position)
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                let center = context.region.center
                if isEcho(of: center) { return }
                // A genuine pan/pinch: the new centre becomes the selection and
                // flows back into the search field.
                reverseGeocode(center)
            }
            .overlay(alignment: .center) {
                // Fixed centre pin: whatever the map centres on is selected.
                Image(systemName: "mappin.circle.fill")
                    .font(.sectionTitle)
                    .foregroundStyle(Theme.brandPrimary)
                    .background(Circle().fill(.white).padding(4))
                    .offset(y: -15)
                    .allowsHitTesting(false)
            }
            .frame(height: mapHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    select(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.bodyText)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.captionText)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if suggestion.id != suggestions.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color.pageBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(8)
    }

    // MARK: - Map ↔ search sync

    /// Whether a camera-change event is the echo of our own `moveCamera` (or
    /// the initial layout) rather than a user gesture. Compared with a small
    /// epsilon because the map can settle a hair off the requested centre.
    private func isEcho(of center: CLLocationCoordinate2D) -> Bool {
        guard let programmatic = lastProgrammaticCenter else { return false }
        return abs(programmatic.latitude - center.latitude) < 1e-5
            && abs(programmatic.longitude - center.longitude) < 1e-5
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        lastProgrammaticCenter = coordinate
        withAnimation(.easeInOut(duration: 0.3)) {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    /// Sets the search text without triggering a suggestion search.
    private func setSearchText(_ text: String) {
        guard text != searchText else { return }
        suppressNextSearch = true
        searchText = text
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        reverseTask?.cancel()
        reverseTask = Task {
            guard let location = await LocationGeocoding.reverseGeocode(coordinate),
                  !Task.isCancelled
            else { return }
            picked = location
            setSearchText(location.name)
            suggestions = []
        }
    }

    private func select(_ suggestion: LocationSuggestion) {
        picked = suggestion.location
        setSearchText(suggestion.location.name)
        suggestions = []
        moveCamera(to: suggestion.location.coordinate)
    }

    // MARK: - Search

    /// Debounce typing before firing a search request.
    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    private func runSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchTask = Task { await performSearch(query: trimmed) }
    }

    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }
        let results = await LocationGeocoding.search(query: query, near: visibleRegion)
        guard !Task.isCancelled else { return }
        suggestions = results
    }

    private func clearSearch() {
        searchTask?.cancel()
        reverseTask?.cancel()
        searchText = ""
        suggestions = []
        isSearching = false
        picked = nil
    }
}

/// A flattened, identifiable search hit ready to apply to the picker.
struct LocationSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let location: PickedLocation
}

/// Forward/reverse geocoding helpers shared by the picker. iOS 26 uses the
/// modern MapKit requests; earlier releases fall back to `CLGeocoder`.
enum LocationGeocoding {
    /// The app's launch market; used only when geocoding can't name a country.
    private static let fallbackCountry = "Australia"

    static func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> PickedLocation? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first
            else { return nil }
            return pickedLocation(from: item, at: coordinate)
        } else {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            else { return nil }
            return pickedLocation(from: placemark, at: coordinate)
        }
    }

    static func search(query: String, near region: MKCoordinateRegion) async -> [LocationSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }
        return response.mapItems.prefix(8).compactMap { item in
            guard let location = suggestionLocation(from: item) else { return nil }
            return LocationSuggestion(
                title: item.name ?? location.name,
                subtitle: suggestionSubtitle(from: item),
                location: location
            )
        }
    }

    // MARK: - MKMapItem / CLPlacemark mapping

    private static func suggestionLocation(from item: MKMapItem) -> PickedLocation? {
        if #available(iOS 26.0, *) {
            let coordinate = item.location.coordinate
            var location = pickedLocation(from: item, at: coordinate)
            // Prefer the POI's own name as the display string when it has one.
            if let name = item.name, !name.isEmpty { location?.name = name }
            return location
        } else {
            let placemark = item.placemark
            var location = pickedLocation(from: placemark, at: placemark.coordinate)
            if let name = item.name, !name.isEmpty { location?.name = name }
            return location
        }
    }

    private static func suggestionSubtitle(from item: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            if let full = item.address?.fullAddress, !full.isEmpty { return full }
            let repr = item.addressRepresentations
            let parts = [repr?.cityName, repr?.regionName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } else {
            let placemark = item.placemark
            let parts = [placemark.locality, placemark.administrativeArea].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
    }

    @available(iOS 26.0, *)
    private static func pickedLocation(
        from item: MKMapItem, at coordinate: CLLocationCoordinate2D
    ) -> PickedLocation? {
        let repr = item.addressRepresentations
        guard let city = repr?.cityName ?? item.name else { return nil }
        let region = repr?.regionName
        let name = [city, region].compactMap { $0 }.joined(separator: ", ")
        return PickedLocation(
            name: name.isEmpty ? city : name,
            city: city,
            stateRegion: region,
            // The modern address representations don't expose a country field;
            // take the full address' last component before falling back.
            country: country(fromFullAddress: item.address?.fullAddress) ?? fallbackCountry,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private static func pickedLocation(
        from placemark: CLPlacemark, at coordinate: CLLocationCoordinate2D
    ) -> PickedLocation? {
        guard let city = placemark.locality ?? placemark.name else { return nil }
        let region = placemark.administrativeArea
        let name = [city, region].compactMap { $0 }.joined(separator: ", ")
        return PickedLocation(
            name: name.isEmpty ? city : name,
            city: city,
            stateRegion: region,
            country: placemark.country ?? fallbackCountry,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    /// Best-effort country from a ", "-joined full address ("1 Macquarie St,
    /// Sydney NSW 2000, Australia" → "Australia").
    private static func country(fromFullAddress fullAddress: String?) -> String? {
        guard let last = fullAddress?
            .components(separatedBy: ",")
            .last?
            .trimmingCharacters(in: .whitespaces),
            !last.isEmpty, !last.contains(where: \.isNumber)
        else { return nil }
        return last
    }
}

#Preview {
    @Previewable @State var picked: PickedLocation?
    return LocationPickerMap(picked: $picked)
        .padding(20)
}
