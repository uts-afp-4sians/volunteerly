import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RegionSelectionView: View {
    @Binding var selectedRegion: String
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    @StateObject private var locationManager = LocationManager()

    // The location the user picked via search. When set, it overrides the GPS
    // location for both the map marker and the Confirm result.
    @State private var pickedCoordinate: Coordinate? = nil
    @State private var pickedName: String? = nil

    // Search-as-you-type state.
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil

    // The region currently shown on the map, biases the search toward it.
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    // Position state of the map (initially centered on Sydney)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))

    /// The coordinate/name to display: the searched pick wins over GPS.
    private var displayCoordinate: Coordinate? {
        pickedCoordinate ?? locationManager.currentCoordinate
    }
    private var displayName: String? {
        pickedName ?? locationManager.currentLocationName
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search Bar matching the mockup
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
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
                            .foregroundStyle(.secondary)
                    }
                }
                MicButton(text: $searchText)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(.systemGray6), in: Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Map Frame matching the mockup
            ZStack(alignment: .top) {
                if let coordinate = displayCoordinate {
                    Map(position: $position) {
                        Marker(displayName ?? "Current Location", coordinate: coordinate.clLocationCoordinate2D)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onMapCameraChange { context in
                        visibleRegion = context.region
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                        .overlay(
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Detecting your location...")
                                    .font(.subheading)
                                    .foregroundStyle(.secondary)
                            }
                        )
                }

                // Search results overlay anchored to the top of the map.
                if !searchResults.isEmpty {
                    searchResultsList
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .padding(.horizontal, 20)

            if let error = locationManager.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fieldError)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Confirm Button matching the mockup
            Button {
                if let pickedName {
                    selectedRegion = pickedName
                } else if let detectedName = locationManager.currentLocationName {
                    selectedRegion = detectedName
                } else if !searchText.isEmpty {
                    selectedRegion = searchText
                } else {
                    selectedRegion = "Ultimo, NSW" // Fallback to mockup value if everything fails
                }
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestPermissionAndLocation()
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearch(query: newValue)
        }
        .onChange(of: locationManager.currentCoordinate) { _, newCoordinate in
            // Don't fight a user-picked location when GPS resolves late.
            guard pickedCoordinate == nil, let coord = newCoordinate else { return }
            position = .region(MKCoordinateRegion(
                center: coord.clLocationCoordinate2D,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                Button {
                    select(result)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.bodyText)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            if let subtitle = result.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 13))
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
                if result.id != searchResults.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(Color.pageBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(8)
    }

    /// Debounce typing before firing a search request.
    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
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

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = visibleRegion

        guard let response = try? await MKLocalSearch(request: request).start() else {
            searchResults = []
            return
        }
        guard !Task.isCancelled else { return }

        searchResults = response.mapItems.prefix(8).map { LocationSearchResult($0) }
    }

    private func select(_ result: LocationSearchResult) {
        pickedCoordinate = result.coordinate
        pickedName = result.title
        position = .region(MKCoordinateRegion(
            center: result.coordinate.clLocationCoordinate2D,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        searchResults = []
        searchText = result.title
        locationManager.errorMessage = nil
    }

    private func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        pickedCoordinate = nil
        pickedName = nil
        if let coord = locationManager.currentCoordinate {
            position = .region(MKCoordinateRegion(
                center: coord.clLocationCoordinate2D,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
}

/// A flattened, identifiable view model for an `MKMapItem` search hit.
struct LocationSearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let coordinate: Coordinate

    init(_ mapItem: MKMapItem) {
        self.title = mapItem.name ?? "Unknown location"
        // Build a readable secondary line from the modern address representation.
        if let full = mapItem.address?.fullAddress, !full.isEmpty {
            self.subtitle = full
        } else {
            let repr = mapItem.addressRepresentations
            let parts = [repr?.cityName, repr?.regionName].compactMap { $0 }
            self.subtitle = parts.isEmpty ? nil : parts.joined(separator: ", ")
        }
        self.coordinate = Coordinate(mapItem.location.coordinate)
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocationName: String? = nil
    @Published var currentCoordinate: Coordinate? = nil
    @Published var isLocating = false
    @Published var errorMessage: String? = nil
    
    override init() {
        super.init()
        manager.delegate = self
        self.authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermissionAndLocation() {
        isLocating = true
        errorMessage = nil
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied. Enable in Settings."
            isLocating = false
        @unknown default:
            isLocating = false
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLocating = false
            return
        }
        
        let coordinate = location.coordinate
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentCoordinate = Coordinate(coordinate)
            
            // MapKit's MKReverseGeocodingRequest to replace deprecated CLGeocoder
            guard let request = MKReverseGeocodingRequest(location: location) else {
                self.errorMessage = "Could not create geocoding request."
                self.isLocating = false
                return
            }
            do {
                let mapItems = try await request.mapItems
                if let mapItem = mapItems.first {
                    if let short = mapItem.address?.shortAddress, !short.isEmpty {
                        self.currentLocationName = short
                    } else if let city = mapItem.addressRepresentations?.cityName, !city.isEmpty {
                        self.currentLocationName = city
                    } else if let full = mapItem.address?.fullAddress, !full.isEmpty {
                        self.currentLocationName = full
                    } else {
                        self.errorMessage = "Could not resolve location."
                    }
                } else {
                    self.errorMessage = "No location items found."
                }
            } catch {
                self.errorMessage = "Error detecting location: \(error.localizedDescription)"
            }
            self.isLocating = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = "Error: \(error.localizedDescription)"
    }
}

/// Equatable value wrapper for a coordinate.
///
/// We deliberately avoid conforming `CLLocationCoordinate2D` to `Equatable`
/// ourselves: it's an imported type and the framework may add its own
/// conformance in the future, which would conflict with ours.
struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
