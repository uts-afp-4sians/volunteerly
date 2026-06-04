import SwiftUI

struct SplashView: View {
    @Environment(AppRouter.self) var router

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
            router.route = SessionManager.shared.hasSession ? .main : .auth
        }
    }
}

#Preview { SplashView().environment(AppRouter()) }
