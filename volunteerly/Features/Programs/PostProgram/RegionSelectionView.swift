import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RegionSelectionView: View {
    @Binding var selectedRegion: String
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    @StateObject private var locationManager = LocationManager()
    
    // Position state of the map (initially centered on Sydney)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))

    var body: some View {
        VStack(spacing: 16) {
            // Search Bar matching the mockup
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Color(.systemGray6), in: Capsule())
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Map Frame matching the mockup
            ZStack {
                if let coordinate = locationManager.currentCoordinate {
                    Map(position: $position) {
                        Marker(locationManager.currentLocationName ?? "Current Location", coordinate: coordinate)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                if let detectedName = locationManager.currentLocationName {
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
        .onChange(of: locationManager.currentCoordinate) { _, newCoordinate in
            if let coord = newCoordinate {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocationName: String? = nil
    @Published var currentCoordinate: CLLocationCoordinate2D? = nil
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
            self.currentCoordinate = coordinate
            
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

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
