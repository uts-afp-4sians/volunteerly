import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RegionSelectionView: View {
    @Binding var selectedRegion: String
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    @StateObject private var locationManager = LocationManager()

    let regions = [
        "New South Wales (NSW)",
        "Victoria (VIC)",
        "Queensland (QLD)",
        "Western Australia (WA)",
        "South Australia (SA)",
        "Tasmania (TAS)",
        "Australian Capital Territory (ACT)",
        "Northern Territory (NT)"
    ]

    var filteredRegions: [String] {
        if searchText.isEmpty {
            return regions
        } else {
            return regions.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if locationManager.isLocating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Auto-detecting current location...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.brand)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.brand.opacity(0.08))
            } else if let error = locationManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fieldError)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fieldError)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.fieldError.opacity(0.08))
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search regions", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color(.systemGray6), in: Capsule())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredRegions, id: \.self) { region in
                        Button {
                            selectedRegion = region
                            dismiss()
                        } label: {
                            HStack {
                                Text(region)
                                    .font(.bodyText)
                                    .foregroundStyle(selectedRegion == region ? Color.brand : .primary)
                                Spacer()
                                if selectedRegion == region {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.brand)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedRegion == region ? Color.brand : Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.pageBackground)
        .navigationTitle("Select Region")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestPermissionAndLocation()
        }
        .onChange(of: locationManager.currentLocationName) { _, newValue in
            if let detected = newValue {
                selectedRegion = detected
                dismiss()
            }
        }
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocationName: String? = nil
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
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
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
