import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack {
            Text("Set Up Your Profile")
                .font(.largeTitle.bold())
            Text("Coming soon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview { OnboardingView() }
