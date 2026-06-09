import SwiftUI

struct LoginView: View {
    // Optional — see WelcomeView: an animated route switch can re-evaluate this
    // view outside the `.environment(router)` scope, where a non-optional
    // @Environment lookup would `fatalError`.
    @Environment(AppRouter.self) private var router: AppRouter?

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            form
            submitButton
            dividerRow
            socialButtons
            Spacer(minLength: 24)
            signupPrompt
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Log in to continue your volunteering journey")
                .font(.bodyText.italic())
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(placeholder: "Email", text: $email) {
                TextField("", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            field(placeholder: "Password", text: $password) {
                SecureField("", text: $password)
                    .textContentType(.password)
            }
            NavigationLink(value: AuthRoute.resetPassword) {
                Text("Forgot Password?")
                    .font(.bodyText)
                    .underline()
                    .foregroundStyle(Theme.forestLight)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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
                    Text("Login").font(.bodyText)
                }
            }
            .foregroundStyle(Theme.onBrand)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.forest)
            .clipShape(Capsule())
        }
        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            line
            Text("Or").font(.bodyText).foregroundStyle(Theme.textSecondary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    private var socialButtons: some View {
        VStack(spacing: 16) {
            socialButton(title: "Continue with Apple")
            socialButton(title: "Continue with Google")
            socialButton(title: "Continue with Facebook")
        }
    }

    private func socialButton(title: String) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.bodyText.italic())
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var signupPrompt: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(Theme.textPrimary)
            NavigationLink(value: AuthRoute.signup) {
                Text("Sign Up!")
                    .underline()
                    .foregroundStyle(Theme.forestLight)
            }
        }
        .font(.bodyText.italic())
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Field helper

    private func field<Content: View>(
        placeholder: String,
        text: Binding<String>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.bodyText.italic())
                    .foregroundStyle(Theme.textSecondary)
            }
            content()
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await AuthService.shared.login(email: email, password: password)
            router?.route = .main
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#Preview {
    AuthFlowView()
        .environment(AppRouter())
        .environment(UserProfileStore())
}
