import SwiftUI

struct SplashView: View {
    // Optional: an animated route switch can re-evaluate this view as it leaves
    // the hierarchy, outside the `.environment(router)` scope; a non-optional
    // lookup would `fatalError` there. See WelcomeView for the same rationale.
    @Environment(AppRouter.self) var router: AppRouter?

    var body: some View {
        VStack(spacing: 16) {
            Image(.logo)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
            
            Text("Volunteerly")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .task {
            try? await Task.sleep(for: .seconds(2))
            router?.route = SessionManager.shared.hasSession ? .main : .auth
        }
    }
}

#Preview { SplashView().environment(AppRouter()) }
