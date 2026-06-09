import SwiftUI
import PhotosUI

struct SignupFormView: View {
    let basics: SignupBasics

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(UserProfileStore.self) private var profileStore

    @State private var step = 2
    private let totalSteps = 4

    // Step 2 — Interests. The catalogue is loaded from the backend `/interests`
    // endpoint (the DB-flagged interest keywords); emoji are mapped client-side
    // by name via `UserProfileStore.emoji(for:)`.
    @State private var selectedInterests: Set<String> = []
    @State private var customInterests: [(emoji: String, name: String)] = []
    @State private var showAddInterestAlert = false
    @State private var newInterestName = ""
    @State private var interestCatalog: [Keyword] = []
    @State private var isLoadingInterests = false
    @State private var interestsLoadFailed = false

    private let profileService = ProfileService.shared

    // Step 3 — Make your own profile
    @State private var profileItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var displayName = ""
    @State private var expectations = ""
    @State private var occupation = ""
    @State private var keySkills = ""
    @State private var instagram = ""

    // Step 4 — Finalising
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

            if step < 4 {
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
            if step < 4 {
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
        VStack(alignment: .leading, spacing: 8) {
            ProgressBar(progress: Double(step) / Double(totalSteps))
            Text("Step \(step) of \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Step switch

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 2: interestsStep
        case 3: makeProfileStep
        case 4: finalisingStep
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

    // MARK: Step 2 — Interests

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What are your interests?")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            if isLoadingInterests {
                ProgressView()
                    .tint(Theme.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else if interestsLoadFailed {
                interestsErrorView
            } else {
                FlowLayout(spacing: 10, lineSpacing: 12) {
                    ForEach(interestCatalog) { keyword in
                        interestChip(emoji: UserProfileStore.emoji(for: keyword.name),
                                     name: keyword.name)
                    }
                }
                ForEach(customInterests, id: \.name) { interest in
                    interestChip(emoji: interest.emoji, name: interest.name)
                }
                addMoreChip
            }
        }
        .task { await loadInterests() }
        .alert("Add an interest", isPresented: $showAddInterestAlert) {
            TextField("Interest name", text: $newInterestName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { newInterestName = "" }
            Button("Add") { commitNewInterest() }
        } message: {
            Text("Tell us about something else you care about.")
        }
    }

    private var interestsErrorView: some View {
        VStack(spacing: 12) {
            Text("Couldn't load interests.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Button("Try again") {
                Task { await loadInterests(force: true) }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.forest)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    /// Fetch the interest catalogue from the backend once. Re-fetches when
    /// `force` is set (the retry button), since a successful load leaves the
    /// catalogue populated and subsequent appearances are no-ops.
    private func loadInterests(force: Bool = false) async {
        guard force || interestCatalog.isEmpty else { return }
        isLoadingInterests = true
        interestsLoadFailed = false
        defer { isLoadingInterests = false }
        do {
            interestCatalog = try await profileService.fetchInterestCatalog()
        } catch {
            interestsLoadFailed = true
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
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? Theme.forest.opacity(0.15) : Color(.systemGray6))
            .overlay(
                Capsule()
                    .stroke(selected ? Theme.forest : Color.clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var addMoreChip: some View {
        Button {
            showAddInterestAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add more")
                    .font(.body)
            }
            .foregroundStyle(Theme.forest)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.forest.opacity(0.08))
            .overlay(
                Capsule()
                    .stroke(Theme.forest, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func commitNewInterest() {
        let trimmed = newInterestName.trimmingCharacters(in: .whitespacesAndNewlines)
        newInterestName = ""
        guard !trimmed.isEmpty else { return }
        let allNames = interestCatalog.map(\.name) + customInterests.map(\.name)
        guard !allNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            selectedInterests.insert(trimmed)
            return
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            customInterests.append((emoji: "✨", name: trimmed))
            selectedInterests.insert(trimmed)
        }
    }

    // MARK: Step 3 — Make your own profile

    private var makeProfileStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Make your own Profile !")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            profileUploadColumn

            VStack(alignment: .leading, spacing: 20) {
                profileField(label: "Name",
                             placeholder: "",
                             text: $displayName)
                profileField(label: "What do you expect from volunteering",
                             placeholder: "",
                             text: $expectations)
                profileField(label: "Current occupation",
                             placeholder: "",
                             text: $occupation)
                profileField(label: "Key skills",
                             placeholder: "e.g. Writing, Social Media, Leadership...",
                             text: $keySkills)
                profileField(label: "Instagram(optional)",
                             placeholder: "",
                             text: $instagram)
            }
        }
    }

    private var profileUploadColumn: some View {
        PhotosPicker(selection: $profileItem, matching: .images) {
            VStack(spacing: 12) {
                profileCircle
                    .frame(width: 110, height: 110)
                Text("Upload a profile picture")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: profileItem) { _, newItem in
            Task { profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
        }
    }

    @ViewBuilder
    private var profileCircle: some View {
        if let data = profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color(.systemGray6))
                Image(systemName: "plus")
                    .font(.title.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func profileField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Step 4 — Finalising

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
                withAnimation(.easeInOut(duration: 0.35)) { router.route = .main }
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
            Text("Next")
                .font(.headline)
                .foregroundStyle(canAdvance ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canAdvance ? Theme.forest : Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(!canAdvance)
    }

    private var canAdvance: Bool {
        switch step {
        case 2: return !selectedInterests.isEmpty
        case 3: return !displayName.isEmpty && !expectations.isEmpty && !occupation.isEmpty && !keySkills.isEmpty
        default: return false
        }
    }

    private func advance() {
        guard step < totalSteps else { return }
        commitCurrentStep()
        step += 1
        if step == 4 { startFinalisingIfNeeded() }
    }

    private func commitCurrentStep() {
        switch step {
        case 2:
            let builtIn = interestCatalog
                .filter { selectedInterests.contains($0.name) }
                .map {
                    UserProfileStore.Interest(
                        emoji: UserProfileStore.emoji(for: $0.name),
                        name: $0.name
                    )
                }
            let custom = customInterests
                .filter { selectedInterests.contains($0.name) }
                .map { UserProfileStore.Interest(emoji: $0.emoji, name: $0.name) }
            profileStore.interests = builtIn + custom
        case 3:
            profileStore.displayName = displayName
            profileStore.instagram = instagram
            profileStore.personalGoal = expectations
            profileStore.occupation = occupation
            profileStore.keySkills = keySkills
            profileStore.profileImageData = profileImageData
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
