import CoreLocation
import Foundation

/// One-shot location read, abstracted so view models can be tested with a
/// stub that returns a fixed coordinate (or never resolves) instead of the
/// real `CLLocationManager`.
@MainActor
protocol LocationProviding {
    func currentCoordinate() async -> CLLocationCoordinate2D?
}

/// Thin async wrapper over `CLLocationManager` for one-shot location reads.
///
/// The program list asks for the device's coordinate to show "1.5km"-style
/// distances on each card. Permission is requested lazily on first use; if the
/// user denies it (or a fix can't be obtained) the call resolves to `nil` and
/// callers fall back to a non-distance UI — no prompt is forced up front.
@MainActor
final class LocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// The device's current coordinate, requesting When-In-Use permission on
    /// first use. Resolves to `nil` when permission is denied/restricted or no
    /// fix can be obtained.
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        // SwiftUI previews can't present the permission prompt; the awaited
        // callback would never arrive, so skip straight to the no-distance UI.
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
        else { return nil }

        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate
    // Callbacks arrive on the main thread (the manager was created here), so
    // `assumeIsolated` is safe and keeps the continuations actor-isolated.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard let continuation = authContinuation else { return }
            authContinuation = nil
            continuation.resume(returning: manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            continuation.resume(returning: locations.first?.coordinate)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            guard let continuation = locationContinuation else { return }
            locationContinuation = nil
            continuation.resume(returning: nil)
        }
    }
}
