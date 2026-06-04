import SwiftUI

enum AppRoute {
    case splash
    case auth
    case onboarding
    case main
}

@MainActor
@Observable
final class AppRouter {
    var route: AppRoute = .splash
}
