import SwiftUI

struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            LoginView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signup:        SignupView()
                    case .signupForm:    SignupFormView()
                    case .resetPassword: ResetPasswordView()
                    }
                }
        }
    }
}

enum AuthRoute: Hashable {
    case signup
    case signupForm
    case resetPassword
}

#Preview { AuthFlowView() }
