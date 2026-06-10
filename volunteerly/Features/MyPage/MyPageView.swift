import SwiftUI
import PhotosUI

/// The signed-in volunteer's "My page" tab: an **editable** My profile form
/// (avatar, name, interests, goal, bio, Instagram + a Save action) followed by
/// the **My program** list (Active / Bookmark tabs, plus a Past sub-list).
///
/// Mirrors Figma `group-4-prototype` node 332:211. The profile editing that used
/// to live on a separate settings screen is integrated here.
struct MyPageView: View {
    // Optional — logout flips the root route to .auth, tearing this view down
    // during an animated switch, when a non-optional lookup would `fatalError`.
    @Environment(AppRouter.self) private var router: AppRouter?
    // Optional so previews that don't inject a router still render (logo tap no-ops).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?
    @Environment(UserProfileStore.self) private var profileStore
    @State private var viewModel: MyPageViewModel

    @State private var profileItem: PhotosPickerItem?
    @State private var showInterestPicker = false
    @State private var didLoad = false

    private let horizontalPadding: CGFloat = 20
    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyPageViewModel(httpClient: httpClient))
    }

    var body: some View {
        @Bindable var store = profileStore

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerRow
                titleRow

                if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dangerColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !store.isHydrated && store.isLoading {
                    // First-ever load with nothing cached: show loading in place
                    // of a blank form. A returning user is hydrated from cache
                    // and skips this entirely.
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else {
                    profileSection
                    interestsAndGoalsSection

                    Divider()

                    editButtons
                }
                programSection
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .tabScrollTopAnchor()
        }
        .scrollsToTop(on: .myPage)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Hydrate once so a re-appearance (tab switch) doesn't clobber edits.
            guard !didLoad else { return }
            didLoad = true
            await store.load()
            await viewModel.load()
        }
        .refreshable {
            // Pull-to-refresh reloads programs only; the profile form keeps edits.
            await viewModel.load()
        }
        .sheet(isPresented: $showInterestPicker) {
            InterestPickerSheet(selected: profileStore.interests) { picked in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    profileStore.interests = picked
                }
            }
        }
    }

    // MARK: - Header

    /// Branding wordmark (taps home) with a trailing Log Out pill — matching the
    /// Figma top bar where logout lives in the header instead of the form footer.
    private var headerRow: some View {
        HStack {
            Button {
                tabRouter?.goHome()
            } label: {
                HStack(spacing: 10) {
                    Image(.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("Volunteerly")
                        .font(.bodyText)
                        .foregroundStyle(Color.textPrimary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Volunteerly, go to home")

            Spacer()
        }
        // Match VolunteerlyHeader's row height (driven by its 32pt avatar) so the
        // logo sits at the same vertical position as on the other tabs.
        .frame(height: 32)
        // Float Log Out as an overlay so its taller pill can't grow the logo row.
        .overlay(alignment: .trailing) {
            Button(action: performLogout) {
                Text("Log Out")
                    .font(.buttonLabel)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray4).opacity(0.87), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log out")
        }
    }

    private var titleRow: some View {
        Text("My Page")
            .font(.pageTitle)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Green section subheader (#7E924E / `Theme.forest`, SF Pro Regular 30).
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheading)
            .foregroundStyle(Theme.forest)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - My profile (editable)

    private var profileSection: some View {
        @Bindable var store = profileStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("My Profile")

            VStack(spacing: 12) {
                PhotosPicker(selection: $profileItem, matching: .images) {
                    Avatar(source: avatarSource(emptyPrompt: true), size: 130)
                }
                .onChange(of: profileItem) { _, newItem in
                    Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                }

                TextField("User name", text: $store.displayName)
                    .textContentType(.name)
                    .multilineTextAlignment(.center)
                    .font(.bodyStrong)
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity)

            instagramField

            TextBox(
                text: $store.aboutMe,
                placeholder: "I am a student, I also enjoy social media marketing",
                height: 120
            )
        }
    }

    /// Single-line grey input for the Instagram handle (TextBox is multi-line).
    private var instagramField: some View {
        @Bindable var store = profileStore
        return TextField(text: $store.instagram) {
            Text("@Instagram ID").font(.labelItalic).foregroundStyle(Theme.textSecondary)
        }
        .font(.bodyText)
        .foregroundStyle(Theme.textPrimary)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color(red: 0.959, green: 0.959, blue: 0.959), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Interests and Goals

    private var interestsAndGoalsSection: some View {
        @Bindable var store = profileStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Interests and Goals")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(profileStore.interests) { interest in
                    interestChip(interest)
                }
                addInterestChip
            }

            TextBox(
                text: $store.personalGoal,
                placeholder: "I want to find people also interested in improving their leadership skills and care about protecting animal rights.",
                height: 110
            )
        }
    }

    private func interestChip(_ interest: UserProfileStore.Interest) -> some View {
        HStack(spacing: 6) {
            Text(interest.emoji)
            Text(interest.name).font(.bodyText)
            Button {
                removeInterest(interest)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(4)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(interest.name)")
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color(.systemGray6), in: Capsule())
    }

    private var addInterestChip: some View {
        Button {
            showInterestPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add an interest").font(.bodyText)
            }
            .foregroundStyle(Theme.forest)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                Capsule().stroke(Theme.forest, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    /// Cancel (outlined, reverts edits) + Edit profile (filled, saves) — the
    /// Figma footer pair that replaces the single "Save my info" button.
    private var editButtons: some View {
        HStack(spacing: 12) {
            Button(action: cancelEdits) {
                Text("Cancel")
                    .font(.buttonLabel)
                    .foregroundStyle(Theme.forest)
                    .padding(15)
                    .frame(width: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(Theme.forest, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(profileStore.isSaving)

            Button {
                Task { await profileStore.save() }
            } label: {
                if profileStore.isSaving {
                    ProgressView().tint(Color.onBrand)
                } else {
                    Text("Edit profile")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(profileStore.isLoading || profileStore.isSaving)
        }
    }

    // MARK: - My program

    private var programSection: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("My Programs")
                .padding(.top, 8)

            SearchBar(text: $vm.searchQuery)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("Something went wrong", systemImage: "exclamationmark.triangle", description: Text(error))
                .padding(.top, 24)
        } else {
            activeContent
            viewAllPostsLink
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        let active = viewModel.activePrograms
        let past = viewModel.pastPrograms

        if active.isEmpty && past.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 20) {
                ForEach(active) { program in
                    MyPageProgramRow(program: program)
                }
            }

            if !past.isEmpty {
                Text("Past")
                    .font(.bodyText)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.top, 12)
                LazyVStack(spacing: 20) {
                    ForEach(past) { program in
                        MyPageProgramRow(program: program, isPast: true)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No programs yet")
            .font(.labelItalic)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    private var viewAllPostsLink: some View {
        // TODO(oma-deferred): route to the volunteer's forum posts when a
        // "my posts" screen exists.
        HStack {
            Spacer()
            Text("View all programs")
                .linkStyle()
            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Account actions

    // MARK: - Helpers

    /// Avatar contents: picked image > saved CDN image > fallback.
    /// `emptyPrompt` chooses the camera "upload" prompt (in the editable picker)
    /// over the plain silhouette (the decorative title badge).
    private func avatarSource(emptyPrompt: Bool) -> Avatar.Source {
        if let data = profileStore.profileImageData, let uiImage = UIImage(data: data) {
            return .image(Image(uiImage: uiImage))
        }
        if let urlString = profileStore.profileImageURL, let url = URL(string: urlString) {
            return .remote(url)
        }
        return emptyPrompt ? .uploadPrompt : .placeholder
    }

    // MARK: - Actions

    private func removeInterest(_ interest: UserProfileStore.Interest) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            profileStore.interests.removeAll { $0.id == interest.id }
        }
    }

    /// Discard unsaved edits by re-applying the cached (last-saved) profile.
    private func cancelEdits() {
        profileStore.revertToCache()
    }

    private func performLogout() {
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) {
            router?.route = .auth
        }
    }
}

/// A single program row in the My program list: thumbnail + name.
struct MyPageProgramRow: View {
    let program: Program
    /// Past programs render in a muted style.
    var isPast: Bool = false

    var body: some View {
        NavigationLink(value: program.id) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 69, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(program.name)
                    .font(.bodyStrong)
                    .foregroundStyle(isPast ? Theme.textSecondary : Color.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        MyPageView(httpClient: MockHTTPClient.shared)
            .navigationDestination(for: Int.self) { id in
                ProgramDetailView(programId: id, httpClient: MockHTTPClient.shared)
            }
    }
    .environment(AppRouter())
    .environment(UserProfileStore())
}
