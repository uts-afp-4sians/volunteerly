import SwiftUI

struct AuthFlowView: View {
    @Environment(AppRouter.self) private var router: AppRouter?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LoginView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signup:                  SignupView()
                    case .signupForm(let basics):  SignupFormView(basics: basics)
                    case .resetPassword:           ResetPasswordView()
                    }
                }
        }
        .onAppear {
            // Land on a specific auth destination when the caller (e.g. HomeView's
            // Sign Up button) asked for one, then clear the request so a later
            // entry from a different door (e.g. Log In) lands on the root.
            if let pending = router?.pendingAuthRoute {
                path.append(pending)
                router?.pendingAuthRoute = nil
            }
        }
    }
}

enum AuthRoute: Hashable {
    case signup
    case signupForm(SignupBasics)
    case resetPassword
}

/// Step 1 (Introduction) fields, carried into the SignupForm via the route.
/// Photo + Instagram now live on `SignupFormViewModel` (step 2), and
/// email/password are collected in the form (step 4) — see the 6-step flow.
struct SignupBasics: Hashable {
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
}

#Preview {
    AuthFlowView()
        .environment(AppRouter())
        .environment(UserProfileStore())
}
