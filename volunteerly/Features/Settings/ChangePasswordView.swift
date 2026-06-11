import SwiftUI

/// Authenticated password change. Pushed from `SettingsView`'s "Change password"
/// row. Verifies the current password against the backend (`POST
/// /auth/change-password`) and sets a new one; the session token is unaffected.
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var errorMessage: String?

    private let auth = AuthService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if didSucceed {
                    confirmation
                } else {
                    form
                    submitButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(didSucceed ? "Password updated" : "Change password")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(didSucceed
                 ? "Your password has been changed. Use it the next time you log in."
                 : "Enter your current password, then choose a new one of at least \(AuthValidation.minimumPasswordLength) characters.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeled("Current password") {
                secureField("Current password", text: $currentPassword)
                    .textContentType(.password)
            }
            labeled("New password") {
                secureField("New password", text: $newPassword)
                    .textContentType(.newPassword)
            }
            labeled("Confirm new password") {
                secureField("Re-enter new password", text: $confirmPassword)
                    .textContentType(.newPassword)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Update Password").font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.forest)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isSubmitting || !isValid)
        .opacity(isValid ? 1 : 0.6)
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.success)
                Text("Password changed")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.forest)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    // MARK: Helpers

    /// Both new-password entries match and clear the minimum length, and the
    /// current-password field isn't empty. The new password must differ from
    /// the current one.
    private var isValid: Bool {
        !currentPassword.isEmpty
            && AuthValidation.isValidPassword(newPassword)
            && newPassword == confirmPassword
            && newPassword != currentPassword
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(Theme.textSecondary)
            SecureField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await auth.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            didSucceed = true
        } catch APIError.unauthorized {
            errorMessage = "Current password is incorrect."
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    NavigationStack { ChangePasswordView() }
}
