import SwiftUI

/// Post-signup welcome moment ("Loading Screen" in Figma). Shown once a new
/// account is created; advances to the main app (Programs list) when tapped or
/// automatically after a short delay.
struct WelcomeView: View {
    // Optional: this view is removed by an animated route switch, during which
    // SwiftUI may re-evaluate it outside the `.environment(router)` scope. A
    // non-optional lookup would hit `fatalError` ("No Observable object of type
    // AppRouter found") at that moment; an optional one resolves to nil safely.
    @Environment(AppRouter.self) private var router: AppRouter?

    /// Guards against advancing twice (tap racing the auto-advance timer).
    @State private var hasAdvanced = false

    private let autoAdvanceDelay: Duration = .seconds(3)

    var body: some View {
        Text("Your teammates are\nwaiting for you")
            .font(.pageTitle)
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .contentShape(Rectangle())
            .onTapGesture { advance() }
            .task {
                try? await Task.sleep(for: autoAdvanceDelay)
                advance()
            }
            .accessibilityElement()
            .accessibilityLabel("Your teammates are waiting for you")
            .accessibilityHint("Tap to continue to programs")
            .accessibilityAddTraits(.isButton)
    }

    private func advance() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        withAnimation(.easeInOut(duration: 0.35)) { router?.route = .main }
    }
}

#Preview {
    WelcomeView()
        .environment(AppRouter())
}
