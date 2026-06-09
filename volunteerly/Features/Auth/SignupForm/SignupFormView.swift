import SwiftUI

struct SignupFormView: View {
    let basics: SignupBasics

    @Environment(\.dismiss) private var dismiss
    // Optional — see WelcomeView: this pushed view is torn down by an animated
    // route switch (.onboarding), during which a non-optional @Environment
    // lookup for AppRouter would `fatalError`.
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(UserProfileStore.self) private var profileStore

    @State private var vm: SignupFormViewModel

    init(basics: SignupBasics) {
        self.basics = basics
        _vm = State(wrappedValue: SignupFormViewModel(basics: basics))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProgressBar(progress: Double(vm.step) / Double(vm.totalSteps))

            ScrollView(showsIndicators: false) {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
            }

            if vm.step < 6 {
                nextButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.step < 6 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if vm.step > 2 { vm.step -= 1 } else { dismiss() }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case 2: LocationStepView(vm: vm)
        case 3: InterestsStepView(vm: vm)
        case 4: EmailPasswordStepView(vm: vm)
        case 5: GoalsStepView(vm: vm)
        case 6: FinalisingStepView(vm: vm, router: router)
        default:
            VStack(alignment: .leading, spacing: 12) {
                Text("Step \(vm.step)")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Coming soon")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.advance(profileStore: profileStore, router: router)
            }
        } label: {
            Text(vm.step == 5 ? "Find your people!" : "Next")
                .font(.buttonLabel)
                .foregroundStyle(vm.canAdvance ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(vm.canAdvance ? Theme.forest : Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .disabled(!vm.canAdvance)
    }
}

#Preview {
    NavigationStack {
        SignupFormView(basics: SignupBasics(
            firstName: "Ada",
            lastName: "Lovelace",
            email: "ada@example.com",
            password: "password123"
        ))
    }
    .environment(AppRouter())
    .environment(UserProfileStore())
}
