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

    // Step 3 — Interests
    var selectedInterests: Set<String> = []
    var interestCatalog: [Keyword] = []
    var isLoadingInterests = false

    // Step 4 — Secure your account
    var email = ""
    var password = ""

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
        case 4: return !email.isEmpty && !password.isEmpty
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
        guard !name.isEmpty, let request = MKGeocodingRequest(addressString: name) else { return }
        isGeocodingCity = true
        Task {
            defer { isGeocodingCity = false }
            if let coord = (try? await request.mapItems)?.first?.placemark.coordinate {
                withAnimation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ))
                }
            }
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
                try await AuthService.shared.register(
                    email: basics.email,
                    password: basics.password,
                    firstName: basics.firstName,
                    lastName: basics.lastName
                )
            }

            try? await Task.sleep(nanoseconds: 2_500_000_000)

            do {
                _ = try await registration.value
                withAnimation(.easeInOut(duration: 0.35)) { router?.route = .onboarding }
            } catch {
                finalisingError = error.localizedDescription
            }
        }
    }
}
