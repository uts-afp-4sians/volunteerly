import SwiftUI

struct EmailPasswordStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Secure your account")
                .largeTitleStyle()

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
                            .font(.subheadText)
                            .foregroundStyle(Color.fieldError)
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
                            .font(.subheadText)
                            .foregroundStyle(Color.fieldError)
                            .padding(.leading, 4)
                    } else if let passwordError = vm.passwordFieldError {
                        Text(passwordError)
                            .font(.subheadText)
                            .foregroundStyle(Color.fieldError)
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
            FieldLabel(text: label, required: required)
            content()
        }
    }

    private func borderedField<Content: View>(
        isError: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .formFieldSurface()
            .overlay {
                if isError {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.fieldError, lineWidth: 1)
                }
            }
    }
}
