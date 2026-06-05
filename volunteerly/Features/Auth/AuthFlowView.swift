import SwiftUI

struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            LoginView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signup:                  SignupView()
                    case .signupForm(let basics):  SignupFormView(basics: basics)
                    case .resetPassword:           ResetPasswordView()
                    }
                }
        }
    }
}

enum AuthRoute: Hashable {
    case signup
    case signupForm(SignupBasics)
    case resetPassword
}

struct SignupBasics: Hashable {
    let firstName: String
    let lastName: String
    let email: String
    let password: String
}

#Preview { AuthFlowView() }
