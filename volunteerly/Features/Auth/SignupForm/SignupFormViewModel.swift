import SwiftUI
import MapKit
import Observation

@MainActor
@Observable
final class SignupFormViewModel {
    let basics: SignupBasics

    var step = 2
    let totalSteps = 6

    // Step 2 — Location
    var city = ""
    var mapCameraPosition: MapCameraPosition = .automatic
    var isGeocodingCity = false
    var isLocatingUser = false
    var locationError: String?
    private var hasRequestedLocation = false

    // Step 3 — Interests
    var selectedInterests: Set<String> = []
    var interestCatalog: [Keyword] = []
    var isLoadingInterests = false

    // Step 4 — Secure your account
    var email = ""
    var password = ""
    // Inline, server-driven errors surfaced under the step-4 fields. Set when
    // registration fails with a 409 (email taken) or 422 (validation).
    var emailFieldError: String?
    var passwordFieldError: String?

    // Step 5 — Goals
    var expectations = ""
    var occupation = ""
    var keySkills = ""

    // Step 6 — Finalising
    var hasStartedFinalising = false
    var finalisingError: String?

    private let profileService = ProfileService.shared

    init(basics: SignupBasics) {
        self.basics = basics
    }

    var canAdvance: Bool {
        switch step {
        case 2: return !city.isEmpty
        case 3: return selectedInterests.count >= 2
        case 4: return !email.isEmpty && AuthValidation.isValidPassword(password)
        case 5: return !expectations.isEmpty
        default: return false
        }
    }

    var fallbackCatalog: [Keyword] {
        UserProfileStore.interestCatalog.enumerated().map { idx, entry in
            Keyword(id: -(idx + 1), categoryId: 0, name: entry.name)
        }
    }

    func geocodeCity() {
        let name = city
        guard !name.isEmpty else { return }
        locationError = nil
        isGeocodingCity = true
        Task {
            defer { isGeocodingCity = false }
            if let coord = await Self.forwardGeocode(addressString: name) {
                withAnimation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
        }
    }

    func useCurrentLocation() {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true
        isLocatingUser = true
        locationError = nil

        Task {
            defer { isLocatingUser = false }
            guard let coordinate = await LocationProvider.shared.currentCoordinate() else {
                locationError = "Location unavailable. Allow access in Settings or search for your city."
                return
            }

            withAnimation {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                ))
            }

            guard let resolved = await Self.reverseGeocode(coordinate: coordinate) else {
                locationError = "We found your location but couldn't identify the city."
                return
            }

            city = resolved
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        Task {
            guard let newCity = await Self.reverseGeocode(coordinate: coordinate),
                  !newCity.isEmpty
            else {
                return
            }

            city = newCity
        }
    }

    // MARK: - Geocoding helpers
    //
    // iOS 26 introduced `MKGeocodingRequest`/`MKReverseGeocodingRequest`; on
    // earlier releases we fall back to `CLGeocoder`, which covers our minimum
    // deployment target (iOS 18.7).

    private static func forwardGeocode(addressString: String) async -> CLLocationCoordinate2D? {
        if #available(iOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: addressString) else { return nil }
            return (try? await request.mapItems)?.first?.location.coordinate
        } else {
            let placemarks = try? await CLGeocoder().geocodeAddressString(addressString)
            return placemarks?.first?.location?.coordinate
        }
    }

    private static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first
            else {
                return nil
            }
            return item.addressRepresentations?.cityName ?? item.name
        } else {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            else {
                return nil
            }
            return placemark.locality ?? placemark.name
        }
    }

    func loadInterests(force: Bool = false) async {
        guard force || interestCatalog.isEmpty else { return }
        isLoadingInterests = true
        defer { isLoadingInterests = false }
        do {
            let fetched = try await profileService.fetchInterestCatalog()
            interestCatalog = fetched.isEmpty ? fallbackCatalog : fetched
        } catch {
            interestCatalog = fallbackCatalog
        }
    }

    func advance(profileStore: UserProfileStore, router: AppRouter?) {
        guard step < totalSteps else { return }
        commitCurrentStep(profileStore: profileStore)
        step += 1
        if step == 6 { startFinalisingIfNeeded(router: router) }
    }

    private func commitCurrentStep(profileStore: UserProfileStore) {
        switch step {
        case 2:
            profileStore.city = city
        case 3:
            profileStore.interests = interestCatalog
                .filter { selectedInterests.contains($0.name) }
                .map {
                    UserProfileStore.Interest(
                        emoji: UserProfileStore.emoji(for: $0.name),
                        name: $0.name
                    )
                }
        case 5:
            profileStore.personalGoal = expectations
            profileStore.occupation = occupation
            profileStore.keySkills = keySkills
        default:
            break
        }
    }

    // Minimum spinner display — keeps the "Matching you with opportunities…"
    // copy on screen long enough to read.
    func startFinalisingIfNeeded(router: AppRouter?) {
        guard !hasStartedFinalising else { return }
        hasStartedFinalising = true

        Task {
            let registration = Task {
                // Email/password are collected at step 4 (`self.email`/`self.password`).
                // `basics` only carries the step-1 name fields — its email/password
                // are empty, so sending them here is what produced the 422s.
                try await AuthService.shared.register(
                    email: email,
                    password: password,
                    firstName: basics.firstName,
                    lastName: basics.lastName
                )
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)

            do {
                _ = try await registration.value
                withAnimation(.easeInOut(duration: 0.35)) { router?.route = .onboarding }
            } catch let error as APIError {
                handleRegistrationFailure(error)
            } catch {
                finalisingError = error.localizedDescription
            }
        }
    }

    /// Map a failed registration onto the form. Recoverable errors (taken email,
    /// invalid email/password) jump back to step 4 with inline field messages so
    /// the user can fix and retry; anything else stays on the finalising screen.
    private func handleRegistrationFailure(_ error: APIError) {
        switch error {
        case .conflict(let message):
            // 409: email already registered → help text under the email field.
            emailFieldError = message
            returnToAccountStep()
        case .validation(let fields, let message):
            // 422: surface each field's message under its input.
            emailFieldError = fields["email"]
            passwordFieldError = fields["password"]
            if emailFieldError == nil && passwordFieldError == nil {
                // Validation failed on a field this step can't edit (e.g. name).
                finalisingError = message
            } else {
                returnToAccountStep()
            }
        default:
            finalisingError = error.localizedDescription
        }
    }

    private func returnToAccountStep() {
        // Allow finalising to re-run once the user advances back through step 6.
        hasStartedFinalising = false
        finalisingError = nil
        withAnimation(.easeInOut(duration: 0.3)) { step = 4 }
    }
}
