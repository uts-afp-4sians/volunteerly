import SwiftUI

struct SplashView: View {
    // Optional: an animated route switch can re-evaluate this view as it leaves
    // the hierarchy, outside the `.environment(router)` scope; a non-optional
    // lookup would `fatalError` there. See WelcomeView for the same rationale.
    @Environment(AppRouter.self) var router: AppRouter?

    var body: some View {
        VStack(spacing: 24) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            FadingTailSpinner(color: Theme.forest, size: 44, lineWidth: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .task {
            try? await Task.sleep(for: .seconds(2))
            router?.route = SessionManager.shared.hasSession ? .main : .home
        }
    }
}

#Preview { SplashView().environment(AppRouter()) }
