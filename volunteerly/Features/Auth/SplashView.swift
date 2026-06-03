import SwiftUI

struct SplashView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        VStack {
            Image(systemName: "hands.sparkles.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Volunteerly")
                .font(.largeTitle.bold())
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            router.route = SessionManager.shared.hasSession ? .main : .auth
        }
    }
}

#Preview { SplashView().environment(AppRouter()) }
