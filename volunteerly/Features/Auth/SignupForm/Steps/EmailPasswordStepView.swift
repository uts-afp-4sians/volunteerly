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
                    borderedField {
                        TextField("", text: $vm.email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }
                }

                fieldColumn(label: "Password", required: true) {
                    borderedField {
                        SecureField("", text: $vm.password)
                            .textContentType(.newPassword)
                    }
                }
            }
        }
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

    private func borderedField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.bodyText)
            .frame(height: 52)
            .padding(.horizontal, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
