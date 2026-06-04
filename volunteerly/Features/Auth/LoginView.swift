import SwiftUI

struct LoginView: View {
    @Environment(AppRouter.self) private var router

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let client: HTTPClient = MockHTTPClient.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                form
                submitButton
                dividerRow
                socialButtons
                signupPrompt
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Log in to continue your journey.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "Email") {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            field(title: "Password") {
                SecureField("••••••••", text: $password)
                    .textContentType(.password)
            }
            HStack {
                Spacer()
                Button("Forgot password?") {}
                    .font(.subheadline)
                    .foregroundStyle(Theme.forest)
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
                    Text("Log In").font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(isSubmitting || email.isEmpty || password.isEmpty)
        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            line
            Text("or").font(.footnote).foregroundStyle(Theme.textSecondary)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    private var socialButtons: some View {
        VStack(spacing: 12) {
            socialButton(title: "Continue with Apple", icon: "applelogo")
            socialButton(title: "Continue with Google", icon: "globe")
            socialButton(title: "Continue with Facebook", icon: "person.crop.circle")
        }
    }

    private func socialButton(title: String, icon: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                Text(title).font(.headline.weight(.medium))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var signupPrompt: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(Theme.textSecondary)
            NavigationLink(value: AuthRoute.signup) {
                Text("Sign Up")
                    .foregroundStyle(Theme.forest)
                    .fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Field helper

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            content()
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response: AuthResponse = try await client.post(
                "/auth/login",
                body: LoginRequest(email: email, password: password)
            )
            SessionManager.shared.token = response.token
            LiveHTTPClient.shared.authToken = response.token
            router.route = .main
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Theme

private enum Theme {
    static let background  = Color(red: 0.98, green: 0.98, blue: 0.97)  // #FAFAF7
    static let card        = Color.white                                 // #FFFFFF
    static let gold        = Color(red: 0.91, green: 0.63, blue: 0.13)  // #E8A020
    static let forest      = Color(red: 0.11, green: 0.42, blue: 0.23)  // #1D6B3A
    static let textPrimary = Color(red: 0.10, green: 0.10, blue: 0.10)  // #1A1A1A
    static let textSecondary = Color(red: 0.53, green: 0.53, blue: 0.50) // #888880
    static let border      = Color(red: 0.90, green: 0.90, blue: 0.88)
}

#Preview {
    AuthFlowView()
        .environment(AppRouter())
}
