import SwiftUI
import Observation

@MainActor
@Observable
final class SignupFormViewModel {
    let basics: SignupBasics

    // 6 numbered steps drive the progress bar (step 1 is SignupView; the form
    // owns 2–6). The unnumbered finalising loader runs at `totalSteps + 1`.
    var step = 2
    let totalSteps = 6

    // Step 2 — Add your photo (profile photo + Instagram, both optional).
    var profileImageData: Data?
    var instagram = ""

    // Step 3 — Location. The step renders a `LocationPickerMap`, which owns
    // the geocoding; the form keeps the display string plus the structured
    // pick that becomes the profile's location_id at save time.
    var city = ""
    var pickedLocation: PickedLocation?

    // Step 4 — Secure your account
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    // Inline, server-driven errors surfaced under the step-4 fields. Set when
    // registration fails with a 409 (email taken) or 422 (validation).
    var emailFieldError: String?
    var passwordFieldError: String?

    // Step 5 — Interests. The catalog is the program-category taxonomy
    // (interests and categories are one set of 11 causes).
    var selectedInterests: Set<String> = []
    var interestCatalog: [ProgramCategory] = []
    var isLoadingInterests = false

    // Step 6 — Goals
    var expectations = ""
    var occupation = ""
    var keySkills = ""

    // Finalising (loader, unnumbered — step `totalSteps + 1`)
    var hasStartedFinalising = false
    var finalisingError: String?
    // Set once `/auth/register` succeeds, so "Try again" after a failed
    // profile save retries only the save — re-registering would 409 on our
    // own freshly created email.
    private var hasRegistered = false
    /// The in-flight finalising work; exposed so tests can await completion.
    private(set) var finalisingTask: Task<Void, Never>?
    /// Registration seam — `AuthService.shared` is a live singleton, so tests
    /// stub this instead.
    var registerAccount: (String, String, String, String) async throws -> Void = {
        _ = try await AuthService.shared.register(
            email: $0, password: $1, firstName: $2, lastName: $3
        )
    }
    /// Minimum spinner display; tests zero this out.
    var minimumSpinnerNanos: UInt64 = 2_500_000_000

    private let profileService = ProfileService.shared

    init(basics: SignupBasics) {
        self.basics = basics
    }

    var canAdvance: Bool {
        switch step {
        case 2: return true   // photo + Instagram are optional
        case 3: return !city.isEmpty
        case 4:
            return !email.isEmpty
                && AuthValidation.isValidPassword(password)
                && password == passwordConfirmation
        case 5: return selectedInterests.count >= 2
        case 6: return !expectations.isEmpty
        default: return false
        }
    }

    var fallbackCatalog: [ProgramCategory] {
        UserProfileStore.interestCatalog.enumerated().map { idx, entry in
            ProgramCategory(id: -(idx + 1), name: entry.name)
        }
    }

    func loadInterests(force: Bool = false) async {
        guard force || interestCatalog.isEmpty else { return }
        isLoadingInterests = true
        defer { isLoadingInterests = false }
        do {
            let fetched = try await CategoryStore.shared.categories(
                httpClient: profileService.client
            )
            interestCatalog = fetched.isEmpty ? fallbackCatalog : merged(backend: fetched)
        } catch {
            interestCatalog = fallbackCatalog
        }
    }

    /// Merge the backend's category catalog with the iOS-local fallback list,
    /// appending any local entries whose names aren't already on the server.
    /// Lets the picker show interests we've added on the client even if the
    /// backend's seed hasn't been re-run yet — server persistence still uses
    /// only the rows whose category id matches via `resolveInterestIds`.
    private func merged(backend: [ProgramCategory]) -> [ProgramCategory] {
        let backendNames = Set(backend.map { $0.name.lowercased() })
        let extras = fallbackCatalog.filter { !backendNames.contains($0.name.lowercased()) }
        return backend + extras
    }

    func advance(profileStore: UserProfileStore, router: AppRouter?) {
        guard step <= totalSteps else { return }
        commitCurrentStep(profileStore: profileStore)
        step += 1
        // Advancing past the last numbered step (6, Goals) kicks off finalising.
        if step > totalSteps { startFinalisingIfNeeded(profileStore: profileStore, router: router) }
    }

    private func commitCurrentStep(profileStore: UserProfileStore) {
        switch step {
        case 3:
            profileStore.city = city
            profileStore.pickedLocation = pickedLocation
        case 5:
            // Include every selected interest — both catalog picks and any
            // custom names the user typed via the "Add more" chip. Custom names
            // without a matching backend category will be dropped server-side by
            // `resolveInterestIds` but stay visible in the local profile during
            // the session.
            profileStore.interests = selectedInterests.map { name in
                UserProfileStore.Interest(
                    emoji: UserProfileStore.emoji(for: name),
                    name: name
                )
            }
        case 6:
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

        finalisingTask = Task {
            if !hasRegistered {
                let registration = Task {
                    // Email/password are collected at step 4 (`self.email`/`self.password`).
                    // `basics` only carries the step-1 name fields — its email/password
                    // are empty, so sending them here is what produced the 422s.
                    try await registerAccount(
                        email, password, basics.firstName, basics.lastName
                    )
                }

                try? await Task.sleep(nanoseconds: minimumSpinnerNanos)

                do {
                    _ = try await registration.value
                    hasRegistered = true
                } catch let error as APIError {
                    handleRegistrationFailure(error)
                    return
                } catch {
                    finalisingError = error.localizedDescription
                    return
                }
            }

            // Now that we have an auth token, write the fields the form
            // collected (date of birth from step 1, profile photo + instagram
            // from step 2) into the shared store and persist everything via
            // PATCH /me/profile. The My Page identity line is read-only by
            // design, so a dropped save would lose the birthday/city with no
            // way to re-enter them — surface the failure and let the user
            // retry the save (the account itself is already created).
            profileStore.dateOfBirth = basics.dateOfBirth
            profileStore.profileImageData = profileImageData
            profileStore.instagram = instagram
            if await profileStore.save() {
                withAnimation(.easeInOut(duration: 0.35)) { router?.route = .onboarding }
            } else {
                finalisingError = profileStore.errorMessage ?? "Couldn't save your profile."
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
        // Allow finalising to re-run once the user advances back through the flow.
        hasStartedFinalising = false
        finalisingError = nil
        withAnimation(.easeInOut(duration: 0.3)) { step = 4 }
    }
}
