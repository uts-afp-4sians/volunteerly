import SwiftUI
import PhotosUI

struct SignupFormView: View {
    let basics: SignupBasics

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var step = 2
    private let totalSteps = 4

    // Step 2 — Interests. The catalogue is loaded from the backend `/interests`
    // endpoint (the DB-flagged interest keywords); emoji are mapped client-side
    // by name via `UserProfileStore.emoji(for:)`.
    @State private var selectedInterests: Set<String> = []
    @State private var interestCatalog: [Keyword] = []
    @State private var isLoadingInterests = false
    @State private var interestsLoadFailed = false

    private let profileService = ProfileService.shared

    // Step 3 — Make your own profile
    @State private var profileItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var expectations = ""
    @State private var occupation = ""
    @State private var keySkills = ""
    @State private var instagram = ""

    // Step 4 — Finalising
    @State private var hasStartedFinalising = false

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
            }
        }
        .task { await loadInterests() }
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

    // MARK: Step 3 — Make your own profile

    private var makeProfileStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Make your own Profile !")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            profileUploadColumn

            VStack(alignment: .leading, spacing: 20) {
                profileField(label: "what do you expect from volunteering",
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
            Task {
                profileImageData = try? await newItem?.loadTransferable(type: Data.self)
            }
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
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            // TODO: submit signup payload (basics + interests + profile) once /auth/signup is wired
            router.route = .main
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
        case 3: return !expectations.isEmpty && !occupation.isEmpty && !keySkills.isEmpty
        default: return false
        }
    }

    private func advance() {
        guard step < totalSteps else { return }
        step += 1
    }
}

#Preview {
    NavigationStack {
        SignupFormView(basics: SignupBasics(
            firstName: "Ada",
            lastName: "Lovelace",
            email: "ada@example.com",
            password: "password"
        ))
    }
    .environment(AppRouter())
}
