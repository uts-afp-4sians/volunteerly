import SwiftUI

/// Technical / account settings — change password, accessibility, legal docs,
/// danger-zone actions. Pushed onto the current tab's stack by the header's
/// gear button; the profile-content page (name, interests, bio …) lives in
/// `MyPageView` on the Profile tab.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    private static let dangerColor = Color(red: 0xD9 / 255, green: 0x29 / 255, blue: 0x29 / 255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.bodyStrong)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .padding(.horizontal, 20)

                Text("Settings")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 20)

                section(title: "Account") {
                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        rowLabel(icon: "key.fill", label: "Change password")
                    }
                    .buttonStyle(.plain)
                }

                section(title: "Legal") {
                    row(icon: "lock.shield.fill", label: "Privacy policy")
                }

                section(title: "About") {
                    row(icon: "heart.fill", label: "Rate the app")
                }

                accountActions
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This permanently removes your profile and volunteering history. This action can't be undone.")
        }
    }

    // MARK: Sections

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                content()
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
    }

    /// One settings row whose tap currently no-ops — destinations to be wired
    /// up as each sub-page is built.
    private func row(icon: String, label: String) -> some View {
        Button {
            // TODO: route to the dedicated screen for each settings entry.
        } label: {
            rowLabel(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    /// The chrome of a settings row (icon, label, chevron, divider). Shared by
    /// the no-op `row` and the `NavigationLink`-backed entries.
    private func rowLabel(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.forest)
                .frame(width: 24)
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 0.5)
                .padding(.leading, 54)
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
        .padding(.top, 8)
    }

    private func performLogout() {
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) { router?.route = .home }
    }

    private func performDelete() {
        // TODO: call DELETE /me once the backend endpoint exists.
        AuthService.shared.logout()
        withAnimation(.easeInOut(duration: 0.35)) { router?.route = .home }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppRouter())
        .environment(TabRouter())
}
