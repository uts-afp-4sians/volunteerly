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
    @State private var viewModel: MyPageViewModel

    @State private var profileItem: PhotosPickerItem?
    @State private var showDeleteConfirmation = false
    @State private var showInterestPicker = false
    @State private var didLoad = false

    private let horizontalPadding: CGFloat = 24
    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyPageViewModel(httpClient: httpClient))
    }

    var body: some View {
        @Bindable var store = profileStore

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                wordmark
                titleRow

                if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dangerColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                profileSection
                saveButton
                programSection
                accountActions
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
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
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This permanently removes your profile and volunteering history. This action can't be undone.")
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

    private var wordmark: some View {
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

    private var titleRow: some View {
        Text("My page")
            .font(.pageTitle)
            .foregroundStyle(Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - My profile (editable)

    private var profileSection: some View {
        @Bindable var store = profileStore
        return VStack(alignment: .leading, spacing: 20) {
            Text("My profile")
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)

            VStack(spacing: 12) {
                PhotosPicker(selection: $profileItem, matching: .images) {
                    Avatar(source: avatarSource(emptyPrompt: true), size: 130)
                }
                .onChange(of: profileItem) { _, newItem in
                    Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                }

                TextField("Name", text: $store.displayName)
                    .textContentType(.name)
                    .multilineTextAlignment(.center)
                    .font(.bodyStrong)
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxWidth: .infinity)

            interestsEditor

            editableMultiline(
                label: "What I hope to get out of this is",
                placeholder: "Meet people who care about the same things I do",
                text: $store.personalGoal,
                lineLimit: 2...4,
                minHeight: 64
            )

            Divider()

            editableMultiline(
                label: "My bio",
                placeholder: "I am a Student, I can bring social media management",
                text: $store.aboutMe,
                lineLimit: 5...12,
                minHeight: 150
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("If you want to send me the messages")
                    .font(.bodyText)
                    .foregroundStyle(Color.textPrimary)
                TextField("@Instagram ID", text: $store.instagram)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var interestsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My interests")
                .font(.bodyText)
                .foregroundStyle(Color.textPrimary)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(profileStore.interests) { interest in
                    interestChip(interest)
                }
                addInterestChip
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

    private var saveButton: some View {
        Button {
            Task { await profileStore.save() }
        } label: {
            Group {
                if profileStore.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save my info").font(.bodyStrong)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .disabled(profileStore.isLoading || profileStore.isSaving)
    }

    // MARK: - My program

    private var programSection: some View {
        @Bindable var vm = viewModel
        return VStack(alignment: .leading, spacing: 16) {
            Text("My program")
                .font(.pageTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 8)

            searchRow(text: $vm.searchQuery)
            tabBar
            content
        }
    }

    private func searchRow(text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(.systemGray6), in: Capsule())
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MyPageProgramTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: MyPageProgramTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(.snappy) { viewModel.selectedTab = tab }
        } label: {
            VStack(spacing: 8) {
                Text(tab.rawValue)
                    .font(.bodyText)
                    .foregroundStyle(isSelected ? Color.brand : Theme.textSecondary)
                Rectangle()
                    .fill(isSelected ? Color.brand : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
            switch viewModel.selectedTab {
            case .active:
                activeContent
            case .bookmark:
                bookmarkContent
            }
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

    @ViewBuilder
    private var bookmarkContent: some View {
        let bookmarks = viewModel.bookmarkPrograms
        if bookmarks.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 20) {
                ForEach(bookmarks) { program in
                    MyPageProgramRow(program: program)
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
            Text("View all posts")
                .linkStyle()
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Account actions

    private var accountActions: some View {
        VStack(spacing: 12) {
            Button(action: performLogout) {
                Text("Log Out")
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.forest, lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirmation = true
            } label: {
                Text("Delete account")
                    .font(.bodyStrong)
                    .foregroundStyle(Self.dangerColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
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

    private func editableMultiline(label: String, placeholder: String, text: Binding<String>, lineLimit: ClosedRange<Int>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Color.textPrimary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(lineLimit)
                .textInputAutocapitalization(.sentences)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func removeInterest(_ interest: UserProfileStore.Interest) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            profileStore.interests.removeAll { $0.id == interest.id }
        }
    }

    private func performLogout() {
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) {
            router?.route = .auth
        }
    }

    private func performDelete() {
        // TODO: call DELETE /me once the backend endpoint exists.
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
