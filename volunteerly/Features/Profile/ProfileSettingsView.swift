import SwiftUI
import PhotosUI

struct ProfileSettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserProfileStore.self) private var profileStore

    @State private var profileItem: PhotosPickerItem?

    @State private var showDeleteConfirmation = false
    @State private var didLoad = false

    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    var body: some View {
        @Bindable var store = profileStore

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageTitle

                if let error = store.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Self.dangerColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("My profile")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)

                // Centered avatar with the name directly beneath it.
                VStack(spacing: 12) {
                    PhotosPicker(selection: $profileItem, matching: .images) {
                        profileCircle
                            .frame(width: 130, height: 130)
                    }
                    .onChange(of: profileItem) { _, newItem in
                        Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                    }

                    TextField("Name", text: $store.displayName)
                        .textContentType(.name)
                        .multilineTextAlignment(.center)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    Text("My interests")
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(store.interests) { interest in
                            interestChip(interest)
                        }
                        addInterestChip
                    }
                }

                multilineField(
                    label: "What I hope to get out of this is",
                    placeholder: "Meet people who care about the same things I do",
                    text: $store.personalGoal,
                    lineLimit: 2...4,
                    minHeight: 70
                )

                Divider()

                multilineField(
                    label: "My bio",
                    placeholder: "I am a Student, I can bring social media management",
                    text: $store.aboutMe,
                    lineLimit: 5...12,
                    minHeight: 200
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("If you want to send me the messages")
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary)
                    TextField("@Instagram ID", text: $store.instagram)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                field(label: "Current occupation", text: $store.occupation, autocaps: .sentences, autocorrect: true)
                field(label: "Key skills", text: $store.keySkills, autocaps: .sentences, autocorrect: true)

                accountActions
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await store.save() } }
                        .font(.body.weight(.semibold))
                        .disabled(store.isLoading)
                }
            }
        }
        .tint(Theme.forest)
        .task {
            // Hydrate once per presentation; avoids clobbering edits on every
            // re-appearance.
            guard !didLoad else { return }
            didLoad = true
            await store.load()
        }
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This permanently removes your profile and volunteering history. This action can't be undone.")
        }
    }

    // MARK: Sections

    private var pageTitle: some View {
        Text("My page")
            .font(.largeTitle.bold())
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func interestChip(_ interest: UserProfileStore.Interest) -> some View {
        HStack(spacing: 6) {
            Text(interest.emoji)
            Text(interest.name)
                .font(.body)
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
        .foregroundStyle(Theme.textPrimary)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    /// Catalogue interests not yet picked, offered by the "Add" menu.
    private var availableInterests: [(emoji: String, name: String)] {
        UserProfileStore.interestCatalog.filter { item in
            !profileStore.interests.contains {
                $0.name.caseInsensitiveCompare(item.name) == .orderedSame
            }
        }
    }

    @ViewBuilder
    private var addInterestChip: some View {
        if !availableInterests.isEmpty {
            Menu {
                ForEach(availableInterests, id: \.name) { item in
                    Button {
                        addInterest(emoji: item.emoji, name: item.name)
                    } label: {
                        Text("\(item.emoji)  \(item.name)")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add an interest")
                        .font(.body)
                }
                .foregroundStyle(Theme.forest)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.forest.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Theme.forest, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var accountActions: some View {
        VStack(spacing: 12) {
            Button(action: performLogout) {
                Text("Log Out")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                Text("Delete account")
                    .font(.headline)
                    .foregroundStyle(Self.dangerColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
        }
        .padding(.top, 16)
    }

    // MARK: Helpers

    private func field(label: String, text: Binding<String>, autocaps: TextInputAutocapitalization, autocorrect: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            TextField("", text: text)
                .textInputAutocapitalization(autocaps)
                .autocorrectionDisabled(!autocorrect)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func multilineField(label: String, placeholder: String, text: Binding<String>, lineLimit: ClosedRange<Int>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
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

    @ViewBuilder
    private var profileCircle: some View {
        if let data = profileStore.profileImageData, let uiImage = UIImage(data: data) {
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

    // MARK: Actions

    private func addInterest(emoji: String, name: String) {
        guard !profileStore.interests.contains(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            profileStore.interests.append(UserProfileStore.Interest(emoji: emoji, name: name))
        }
    }

    private func removeInterest(_ interest: UserProfileStore.Interest) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            profileStore.interests.removeAll { $0.id == interest.id }
        }
    }

    private func performLogout() {
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) {
            router.route = .auth
        }
    }

    private func performDelete() {
        // TODO: call DELETE /me once the backend endpoint exists.
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) {
            router.route = .auth
        }
    }
}

#Preview {
    NavigationStack { ProfileSettingsView() }
        .environment(AppRouter())
        .environment(UserProfileStore())
}
