import SwiftUI
import PhotosUI

struct ProfileSettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(UserProfileStore.self) private var profileStore

    @State private var profileItem: PhotosPickerItem?

    @State private var showDeleteConfirmation = false
    @State private var showAddInterestAlert = false
    @State private var newInterestName = ""

    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    var body: some View {
        @Bindable var store = profileStore

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageTitle

                VStack(alignment: .leading, spacing: 20) {
                    Text("My profile")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)

                    HStack(spacing: 24) {
                        PhotosPicker(selection: $profileItem, matching: .images) {
                            profileCircle
                                .frame(width: 110, height: 110)
                        }
                        .onChange(of: profileItem) { _, newItem in
                            Task { store.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            TextField("Your name", text: $store.displayName)
                                .textContentType(.name)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    field(label: "Instagram", text: $store.instagram, autocaps: .never, autocorrect: false)
                    field(label: "About me", text: $store.aboutMe, autocaps: .sentences, autocorrect: true)
                    field(label: "Current occupation", text: $store.occupation, autocaps: .sentences, autocorrect: true)
                    field(label: "Key skills", text: $store.keySkills, autocaps: .sentences, autocorrect: true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("My interests")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(store.interests) { interest in
                                interestChip(interest)
                            }
                            addInterestChip
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("My personal goal (optional)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    TextField("the thing user want to gain through volunteering",
                              text: $store.personalGoal,
                              axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
        .tint(Theme.forest)
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This permanently removes your profile and volunteering history. This action can't be undone.")
        }
        .alert("Add an interest", isPresented: $showAddInterestAlert) {
            TextField("Interest name", text: $newInterestName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { newInterestName = "" }
            Button("Add") { commitNewInterest() }
        } message: {
            Text("Tell us about something else you care about.")
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

    private var addInterestChip: some View {
        Button {
            showAddInterestAlert = true
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

    private func commitNewInterest() {
        let trimmed = newInterestName.trimmingCharacters(in: .whitespacesAndNewlines)
        newInterestName = ""
        guard !trimmed.isEmpty else { return }
        guard !profileStore.interests.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            profileStore.interests.append(UserProfileStore.Interest(emoji: "✨", name: trimmed))
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
