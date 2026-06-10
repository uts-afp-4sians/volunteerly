import SwiftUI

struct EmailPasswordStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Secure your account")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 20) {
                fieldColumn(label: "Email", required: true) {
                    borderedField(isError: vm.emailFieldError != nil) {
                        TextField("", text: $vm.email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            // Editing clears a stale server error (e.g. "email taken").
                            .onChange(of: vm.email) { _, _ in vm.emailFieldError = nil }
                    }

                    if let emailError = vm.emailFieldError {
                        Text(emailError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }

                fieldColumn(label: "Password", required: true) {
                    borderedField(isError: passwordIsError || vm.passwordFieldError != nil) {
                        SecureField("", text: $vm.password)
                            .textContentType(.newPassword)
                            .onChange(of: vm.password) { _, _ in vm.passwordFieldError = nil }
                    }

                    if passwordIsError {
                        Text("Password must be at least \(AuthValidation.minimumPasswordLength) characters")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    } else if let passwordError = vm.passwordFieldError {
                        Text(passwordError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }

                fieldColumn(label: "Confirm password", required: true) {
                    borderedField(isError: passwordMismatchIsError) {
                        SecureField("", text: $vm.passwordConfirmation)
                            .textContentType(.newPassword)
                    }

                    if passwordMismatchIsError {
                        Text("Passwords don't match")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.leading, 4)
                    }
                }
            }
        }
    }

    private var passwordIsError: Bool {
        !vm.password.isEmpty && !AuthValidation.isValidPassword(vm.password)
    }

    /// Only flag a mismatch once the user has typed something in the
    /// confirmation field — otherwise the error would appear on landing.
    private var passwordMismatchIsError: Bool {
        !vm.passwordConfirmation.isEmpty && vm.password != vm.passwordConfirmation
    }

    private func fieldColumn<Content: View>(
        label: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                if required { Text("*").requiredFieldStyle() }
            }
            content()
        }
    }

    private func borderedField<Content: View>(
        isError: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .font(.bodyText)
            .frame(height: 52)
            .padding(.horizontal, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isError ? Color.red : Theme.border, lineWidth: 1)
            )
    }
}
