import SwiftUI
import MapKit

struct SignupFormView: View {
    let basics: SignupBasics

    @Environment(\.dismiss) private var dismiss
    // Optional — see WelcomeView: this pushed view is torn down by an animated
    // route switch (.onboarding), during which a non-optional @Environment
    // lookup for AppRouter would `fatalError`.
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(UserProfileStore.self) private var profileStore

    @State private var step = 2
    private let totalSteps = 6

    // Step 2 — Location
    @State private var city = ""
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var isGeocodingCity = false

    // Step 3 — Interests. Catalogue loads from `/interests`; falls back to the
    // hardcoded list when the backend is unavailable or returns an empty set.
    @State private var selectedInterests: Set<String> = []
    @State private var interestCatalog: [Keyword] = []
    @State private var isLoadingInterests = false

    private let profileService = ProfileService.shared

    // Step 4 — Secure your account
    @State private var email = ""
    @State private var password = ""

    // Step 5 — Goals
    @State private var expectations = ""
    @State private var occupation = ""
    @State private var keySkills = ""

    // Step 6 — Finalising
    @State private var hasStartedFinalising = false
    @State private var finalisingError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            progressHeader

            ScrollView(showsIndicators: false) {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
            }

            if step < 6 {
                nextButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if step < 6 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if step > 2 { step -= 1 } else { dismiss() }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    // MARK: Header

    private var progressHeader: some View {
        ProgressBar(progress: Double(step) / Double(totalSteps))
    }

    // MARK: Step switch

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 2: locationStep
        case 3: interestsStep
        case 4: emailPasswordStep
        case 5: goalsStep
        case 6: finalisingStep
        default: comingSoonStep
        }
    }

    private var comingSoonStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step \(step)")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Coming soon")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Step 2 — Location

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where are you?")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 3) {
                    Text("City")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("*").requiredFieldStyle()
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Search", text: $city)
                        .submitLabel(.search)
                        .onSubmit { geocodeCity() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 0) {
                Map(position: $mapCameraPosition)
                    .frame(height: 280)
                    .disabled(true)

                Button {
                    geocodeCity()
                } label: {
                    HStack(spacing: 8) {
                        if isGeocodingCity {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .controlSize(.small)
                        }
                        Text(isGeocodingCity ? "Searching…" : "Select location")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(city.isEmpty ? Theme.border : Theme.forest)
                }
                .disabled(city.isEmpty || isGeocodingCity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func geocodeCity() {
        let name = city
        guard !name.isEmpty else { return }
        isGeocodingCity = true
        CLGeocoder().geocodeAddressString(name) { placemarks, _ in
            Task { @MainActor in
                self.isGeocodingCity = false
                if let coord = placemarks?.first?.location?.coordinate {
                    withAnimation {
                        self.mapCameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        ))
                    }
                }
            }
        }
    }

    // MARK: Step 3 — Interests

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What are your interests?")
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Pick at least two of the following")
                    .font(.labelItalic)
                    .foregroundStyle(Theme.textSecondary)
            }

            if isLoadingInterests {
                ProgressView()
                    .tint(Theme.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else {
                FlowLayout(spacing: 10, lineSpacing: 12) {
                    ForEach(interestCatalog) { keyword in
                        interestChip(emoji: UserProfileStore.emoji(for: keyword.name),
                                     name: keyword.name)
                    }
                }
            }
        }
        .task { await loadInterests() }
    }

    /// Loads the interest catalogue from the backend.
    /// Falls back to the hardcoded catalog when the backend is unavailable or
    /// returns an empty set, so the signup step is never blocked by a server issue.
    private func loadInterests(force: Bool = false) async {
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

    private var fallbackCatalog: [Keyword] {
        UserProfileStore.interestCatalog.enumerated().map { idx, entry in
            Keyword(id: -(idx + 1), categoryId: 0, name: entry.name)
        }
    }

    private func interestChip(emoji: String, name: String) -> some View {
        let selected = selectedInterests.contains(name)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                if selected {
                    selectedInterests.remove(name)
                } else {
                    selectedInterests.insert(name)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(name)
                    .font(.body)
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? Theme.forest : Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 4 — Secure your account

    private var emailPasswordStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Secure your account")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 20) {
                secureFieldColumn(label: "Email", required: true) {
                    secureBorderedField {
                        TextField("", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }
                }

                secureFieldColumn(label: "Password", required: true) {
                    secureBorderedField {
                        SecureField("", text: $password)
                            .textContentType(.newPassword)
                    }
                }
            }
        }
    }

    private func secureFieldColumn<Content: View>(label: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                if required {
                    Text("*").requiredFieldStyle()
                }
            }
            content()
        }
    }

    private func secureBorderedField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.bodyText)
            .frame(height: 52)
            .padding(.horizontal, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    // MARK: Step 5 — Goals

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What are your\ncurrent goals?")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    Text("What are you hoping to get out of this?")
                        .font(.bodyText)
                        .foregroundStyle(Theme.textPrimary)
                    Text("*").requiredFieldStyle()
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                    if expectations.isEmpty {
                        Text("e.g. Meet people who care about the\nsame social justice programs as I do")
                            .font(.bodyText)
                            .italic()
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $expectations, axis: .vertical)
                        .font(.bodyText)
                        .lineLimit(3...)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                .frame(minHeight: 92)
            }

            optionalDivider

            VStack(alignment: .leading, spacing: 24) {
                goalsTextField(
                    label: "What is your current role?",
                    placeholder: "e.g. Uni student, barista, between jobs...",
                    text: $occupation
                )
                goalsTextField(
                    label: "What do you believe you can bring to a volunteer program team?",
                    placeholder: "e.g. Showing up with good energy!!!",
                    text: $keySkills
                )
            }
        }
    }

    private var optionalDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
            Text("Optional")
                .font(.labelItalic)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize()
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private func goalsTextField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.bodyText)
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .allowsHitTesting(false)
                }
                TextField("", text: text)
                    .font(.bodyText)
                    .padding(.horizontal, 14)
            }
            .frame(height: 52)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Step 6 — Finalising

    private var finalisingStep: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            if finalisingError == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.6)
                    .tint(Theme.forest)

                VStack(spacing: 8) {
                    Text("Setting up your profile")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Matching you with opportunities that fit your interests…")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)

                VStack(spacing: 8) {
                    Text("Couldn't create your account")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text(finalisingError ?? "")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button {
                    finalisingError = nil
                    hasStartedFinalising = false
                    startFinalisingIfNeeded()
                } label: {
                    Text("Try again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .onAppear { startFinalisingIfNeeded() }
    }

    private func startFinalisingIfNeeded() {
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

            // Minimum spinner display — keeps the "Matching you with
            // opportunities…" copy on screen long enough to read.
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            do {
                _ = try await registration.value
                withAnimation(.easeInOut(duration: 0.35)) { router?.route = .onboarding }
            } catch {
                finalisingError = error.localizedDescription
            }
        }
    }

    // MARK: Next

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { advance() }
        } label: {
            Text(step == 5 ? "Find your people!" : "Next")
                .font(.buttonLabel)
                .foregroundStyle(canAdvance ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canAdvance ? Theme.forest : Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .disabled(!canAdvance)
    }

    private var canAdvance: Bool {
        switch step {
        case 2: return !city.isEmpty
        case 3: return selectedInterests.count >= 2
        case 4: return !email.isEmpty && !password.isEmpty
        case 5: return !expectations.isEmpty
        default: return false
        }
    }

    private func advance() {
        guard step < totalSteps else { return }
        commitCurrentStep()
        step += 1
        if step == 6 { startFinalisingIfNeeded() }
    }

    private func commitCurrentStep() {
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
}

#Preview {
    NavigationStack {
        SignupFormView(basics: SignupBasics(
            firstName: "Ada",
            lastName: "Lovelace",
            email: "ada@example.com",
            password: "password123"
        ))
    }
    .environment(AppRouter())
    .environment(UserProfileStore())
}
