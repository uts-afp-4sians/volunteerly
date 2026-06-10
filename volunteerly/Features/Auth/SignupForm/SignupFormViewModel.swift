import SwiftUI
import Observation

@MainActor
@Observable
final class SignupFormViewModel {
    let basics: SignupBasics

    var step = 2
    let totalSteps = 6

    // Step 2 — Location. The step renders a `LocationPickerMap`, which owns
    // the geocoding; the form keeps the display string plus the structured
    // pick that becomes the profile's location_id at save time.
    var city = ""
    var pickedLocation: PickedLocation?

    // Step 3 — Interests
    var selectedInterests: Set<String> = []
    var interestCatalog: [Keyword] = []
    var isLoadingInterests = false

    // Step 4 — Secure your account
    var email = ""
    var password = ""
    var passwordConfirmation = ""
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
        case 4:
            return !email.isEmpty
                && AuthValidation.isValidPassword(password)
                && password == passwordConfirmation
        case 5: return !expectations.isEmpty
        default: return false
        }
    }

    var fallbackCatalog: [Keyword] {
        UserProfileStore.interestCatalog.enumerated().map { idx, entry in
            Keyword(id: -(idx + 1), categoryId: 0, name: entry.name)
        }
    }

    func loadInterests(force: Bool = false) async {
        guard force || interestCatalog.isEmpty else { return }
        isLoadingInterests = true
        defer { isLoadingInterests = false }
        do {
            let fetched = try await profileService.fetchInterestCatalog()
            interestCatalog = fetched.isEmpty ? fallbackCatalog : merged(backend: fetched)
        } catch {
            interestCatalog = fallbackCatalog
        }
    }

    /// Merge the backend's keyword catalogue with the iOS-local fallback list,
    /// appending any local entries whose names aren't already on the server.
    /// Lets the picker show interests we've added on the client even if the
    /// backend's seed hasn't been re-run yet — server persistence still uses
    /// only the rows whose keyword.id matches via `resolveInterestIds`.
    private func merged(backend: [Keyword]) -> [Keyword] {
        let backendNames = Set(backend.map { $0.name.lowercased() })
        let extras = fallbackCatalog.filter { !backendNames.contains($0.name.lowercased()) }
        return backend + extras
    }

    func advance(profileStore: UserProfileStore, router: AppRouter?) {
        guard step < totalSteps else { return }
        commitCurrentStep(profileStore: profileStore)
        step += 1
        if step == 6 { startFinalisingIfNeeded(profileStore: profileStore, router: router) }
    }

    private func commitCurrentStep(profileStore: UserProfileStore) {
        switch step {
        case 2:
            profileStore.city = city
            profileStore.pickedLocation = pickedLocation
        case 3:
            // Include every selected interest — both catalog picks and any
            // custom names the user typed via the "Add more" chip. Custom names
            // without a matching backend keyword will be dropped server-side by
            // `resolveInterestIds` but stay visible in the local profile during
            // the session.
            profileStore.interests = selectedInterests.map { name in
                UserProfileStore.Interest(
                    emoji: UserProfileStore.emoji(for: name),
                    name: name
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
    func startFinalisingIfNeeded(profileStore: UserProfileStore, router: AppRouter?) {
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
                // Now that we have an auth token, write the step-1 fields the
                // form collected (date of birth, profile photo, instagram) into
                // the shared store and persist everything via PATCH /me/profile
                // + PUT /me/interests. Best-effort: the account is already
                // created so we proceed to onboarding even if save() fails —
                // the user can fix anything on the My profile page.
                profileStore.dateOfBirth = basics.dateOfBirth
                profileStore.profileImageData = basics.profileImageData
                profileStore.instagram = basics.instagram
                _ = await profileStore.save()
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
