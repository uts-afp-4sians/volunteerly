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
    @Environment(UserProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MyPageViewModel

    @State private var profileItem: PhotosPickerItem?
    @State private var showInterestPicker = false
    @State private var showDOBPicker = false
    @State private var editingName: String?
    @State private var didLoad = false
    /// `true` for the moment after a successful save and until the user edits
    /// anything else, swapping the Save button's label to "Saved!" as feedback.
    @State private var justSaved = false

    private let horizontalPadding: CGFloat = 20
    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyPageViewModel(httpClient: httpClient))
    }

    var body: some View {
        @Bindable var store = profileStore

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                backRow
                titleRow

                if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dangerColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                profileSection
                interestsAndGoalsSection

                Divider()

                editButtons
                programSection
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .tabScrollTopAnchor()
        }
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

    /// Back chip on its own row at the top, leading into the "My Page" title.
    private var backRow: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 32, height: 32)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
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

            VStack(spacing: 8) {
                PhotosPicker(selection: $profileItem, matching: .images) {
                    Avatar(source: avatarSource(emptyPrompt: true), size: 130)
                        .overlay(alignment: .bottomTrailing) {
                            // Small brand-green "+" badge cueing the user that
                            // tapping the avatar swaps the picture.
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 34, height: 34)
                                .background(Theme.forest, in: Circle())
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        }
                }
                .onChange(of: profileItem) { _, newItem in
                    Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                }

                // Pencil sits immediately to the left of the name; a hidden
                // copy on the right balances the row so the name itself is
                // visually centred on the screen.
                HStack(spacing: 10) {
                    pencilButton

                    Text(store.displayName.isEmpty ? "Your name" : store.displayName)
                        .font(.bodyStrong)
                        .foregroundStyle(store.displayName.isEmpty ? Theme.textSecondary : Color.textPrimary)

                    pencilButton.hidden()
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)

            labelledField("Date of birth") { dateOfBirthRow }
            labelledField("City") {
                singleLineField(text: $store.city, placeholder: "e.g. Sydney")
                    .textInputAutocapitalization(.words)
            }
            labelledField("Instagram") { instagramField }
            labelledField("About me") {
                TextBox(
                    text: $store.aboutMe,
                    placeholder: "I am a student, I also enjoy social media marketing",
                    height: 120
                )
            }
        }
        .alert("Edit name", isPresented: Binding(
            get: { editingName != nil },
            set: { if !$0 { editingName = nil } }
        )) {
            TextField("Your name", text: Binding(
                get: { editingName ?? "" },
                set: { editingName = $0 }
            ))
            .textContentType(.name)
            Button("Cancel", role: .cancel) { editingName = nil }
            Button("Save") {
                if let name = editingName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    profileStore.displayName = name
                }
                editingName = nil
            }
        } message: {
            Text("Update the name shown on your profile.")
        }
        .sheet(isPresented: $showDOBPicker) {
            dateOfBirthSheet
        }
    }

    /// Brand-green pencil pill that opens the name-edit alert. Used twice in
    /// the name row — once visible on the left, once hidden on the right to
    /// keep the name optically centred.
    private var pencilButton: some View {
        Button {
            editingName = profileStore.displayName
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.forest)
                .padding(6)
                .background(Theme.forest.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit name")
    }

    /// Single-line input styled to match the existing instagram / city fields.
    private func singleLineField(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .font(.bodyText)
            .foregroundStyle(Theme.textPrimary)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(red: 0.959, green: 0.959, blue: 0.959), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Field with a small labelled header, used for the new profile rows.
    private func labelledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    /// Read-only date row that opens a graphical date picker on tap.
    private var dateOfBirthRow: some View {
        Button {
            showDOBPicker = true
        } label: {
            HStack {
                Text(formattedDOB)
                    .font(.bodyText)
                    .foregroundStyle(profileStore.dateOfBirth == nil ? Theme.textSecondary : Theme.textPrimary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.forest)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(red: 0.959, green: 0.959, blue: 0.959), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var formattedDOB: String {
        guard let dob = profileStore.dateOfBirth else { return "Choose a date" }
        return dob.formatted(date: .long, time: .omitted)
    }

    private var dateOfBirthSheet: some View {
        VStack(spacing: 0) {
            DatePicker(
                "",
                selection: Binding(
                    get: { profileStore.dateOfBirth ?? Date() },
                    set: { profileStore.dateOfBirth = $0 }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Theme.forest)
            .padding(.horizontal, 8)
            .padding(.top, 24)

            Button { showDOBPicker = false } label: {
                Text("Done")
                    .font(.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

            labelledField("What I hope to get out of this") {
                TextBox(
                    text: $store.personalGoal,
                    placeholder: "I want to find people also interested in improving their leadership skills and care about protecting animal rights.",
                    height: 110
                )
            }

            labelledField("Current role") {
                singleLineField(text: $store.occupation, placeholder: "e.g. Uni student, barista, between jobs")
                    .textInputAutocapitalization(.sentences)
            }

            labelledField("What I can bring to the team") {
                singleLineField(text: $store.keySkills, placeholder: "e.g. Positive energy, strong communication")
                    .textInputAutocapitalization(.sentences)
            }
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
        Button {
            Task {
                if await profileStore.save() {
                    justSaved = true
                }
            }
        } label: {
            if profileStore.isSaving {
                ProgressView().tint(Color.onBrand)
            } else if justSaved && !profileStore.isDirty {
                Text("Saved!")
            } else {
                Text("Save changes")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(profileStore.isLoading || profileStore.isSaving || !profileStore.isDirty)
        .onChange(of: profileStore.isDirty) { _, dirty in
            // Any new edit clears the "Saved!" confirmation so the button can
            // light up again as "Save changes".
            if dirty { justSaved = false }
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
        Text("You haven't joined any program yet.")
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
