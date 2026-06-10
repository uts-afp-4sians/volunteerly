import SwiftUI

enum AppRoute {
    case splash
    case home
    case auth
    case onboarding
    case main
}

@MainActor
@Observable
final class AppRouter {
    var route: AppRoute = .splash
    /// Optional destination handed to `AuthFlowView` when entering `.auth` from
    /// a screen that wants a specific landing page (e.g. HomeView's Sign Up
    /// button pushes straight to `SignupView`). Consumed and cleared by
    /// `AuthFlowView.onAppear`.
    var pendingAuthRoute: AuthRoute?
}
