import SwiftUI
import PhotosUI

/// The signed-in volunteer's "My page" tab: an **editable** My profile form
/// (avatar, name | birthday | city line, Instagram, About Me), the
/// **Interests and Goals** chips + goal text with a Save Changes action,
/// followed by the **My Programs** list (search, active + Past).
///
/// Mirrors Figma `group-4-prototype` node 332:211.
struct MyPageView: View {
    // Optional so previews that don't inject a router still render (gear tap no-ops).
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
                    saveButton

                    Divider()
                }
                programSection
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 24)
            .tabScrollTopAnchor()
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollsToTop(on: .myPage)
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

    /// "My Page" title with a trailing Settings gear. Logout now lives inside
    /// the Settings screen, so the gear is the only header action here.
    private var titleRow: some View {
        HStack(alignment: .center) {
            Text("My Page")
                .largeTitleStyle()

            Spacer()

            Button {
                tabRouter?.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Section subheader — Headline 18 · Black/700 per the Figma frame.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .headlineStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - My profile (editable)

    private var profileSection: some View {
        @Bindable var store = profileStore
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("My Profile")

            VStack(spacing: 16) {
                PhotosPicker(selection: $profileItem, matching: .images) {
                    Avatar(source: avatarSource(emptyPrompt: true), size: 112)
                        .overlay(alignment: .bottomTrailing) {
                            // Brand-green "+" badge cueing the user that tapping
                            // the avatar swaps the picture (Figma: plus.circle.fill).
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.onBrand, Theme.brandPrimary)
                                .background(Circle().fill(Color.white))
                        }
                }
                .onChange(of: profileItem) { _, newItem in
                    Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                }

                identityLine
            }
            .frame(maxWidth: .infinity)

            instagramField

            labelledField("About Me") {
                TextBox(
                    text: $store.aboutMe,
                    placeholder: "I am a student, I also enjoy social media marketing",
                    height: 110
                )
            }
        }
    }

    /// The read-only "Name | Birthday | City of Residence" line under the
    /// avatar; unset segments render as placeholder-coloured prompts.
    private var identityLine: some View {
        (identitySegment(profileStore.displayName.isEmpty ? nil : profileStore.displayName, prompt: "Name")
            + identityDivider
            + identitySegment(formattedDOB, prompt: "Birthday")
            + identityDivider
            + identitySegment(profileStore.city.isEmpty ? nil : profileStore.city, prompt: "City of Residence"))
            .font(.bodyText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private var identityDivider: Text {
        Text(" | ").foregroundColor(Theme.placeholder)
    }

    private func identitySegment(_ value: String?, prompt: String) -> Text {
        Text(value ?? prompt)
            .foregroundColor(value == nil ? Theme.placeholder : Color.textPrimary)
    }

    private var formattedDOB: String? {
        profileStore.dateOfBirth?.formatted(date: .abbreviated, time: .omitted)
    }

    /// Field with a small labelled header, used for the textbox rows.
    private func labelledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    /// Single-line grey input for the Instagram handle (TextBox is multi-line).
    /// Per Figma it sits directly under the identity line with no label.
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

            labelledField("What I hope to get out of this") {
                TextBox(
                    text: $store.personalGoal,
                    placeholder: "I want to find people also interested in improving their leadership skills and care about protecting animal rights.",
                    height: 110
                )
            }
        }
    }

    /// Surface-grey chip per Figma (rounded 20, Callout 15 · Black/700).
    /// Tapping any chip opens the picker, where interests are added/removed.
    private func interestChip(_ interest: UserProfileStore.Interest) -> some View {
        Button {
            showInterestPicker = true
        } label: {
            Text("\(interest.emoji) \(interest.name)")
                .font(.calloutText)
                .foregroundStyle(Theme.textBody)
                .padding(10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(interest.name) interest")
        .accessibilityHint("Opens the interest picker")
    }

    /// Dashed "+ Add" chip per Figma (Brand/400 dashed border, Brand/300 label).
    private var addInterestChip: some View {
        Button {
            showInterestPicker = true
        } label: {
            Text("+ Add")
                .font(.calloutText)
                .foregroundStyle(Theme.brand300)
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.brandPrimary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an interest")
    }

    /// Full-width brand "Save Changes" pill — the Figma footer of the editable form.
    private var saveButton: some View {
        Button {
            Task { await profileStore.save() }
        } label: {
            if profileStore.isSaving {
                ProgressView().tint(Color.onBrand)
            } else {
                Text("Save Changes")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(profileStore.isLoading || profileStore.isSaving || !profileStore.isDirty)
    }

    // MARK: - My Programs

    private var programSection: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader("My Programs")

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
                    .font(.subheadText)
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
}

/// A single program row in the My program list: thumbnail + name.
struct MyPageProgramRow: View {
    let program: Program
    /// Past programs render in a muted style (Figma: Black/300).
    var isPast: Bool = false

    var body: some View {
        NavigationLink(value: program.id) {
            HStack(spacing: 16) {
                CachedAsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Theme.surface)
                }
                .frame(width: 69, height: 69)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(program.name)
                    .font(.bodyStrong)
                    .foregroundStyle(isPast ? Theme.placeholder : Color.textPrimary)
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
