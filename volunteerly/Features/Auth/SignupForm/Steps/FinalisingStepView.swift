import SwiftUI

struct FinalisingStepView: View {
    @Bindable var vm: SignupFormViewModel
    let router: AppRouter?
    @Environment(UserProfileStore.self) private var profileStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            if vm.finalisingError == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.6)
                    .tint(Theme.forest)

                VStack(spacing: 8) {
                    Text("Setting up your profile")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Matching you with opportunities that fit your interests…")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)

                VStack(spacing: 8) {
                    Text("Couldn't create your account")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text(vm.finalisingError ?? "")
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button {
                    vm.finalisingError = nil
                    vm.hasStartedFinalising = false
                    vm.startFinalisingIfNeeded(profileStore: profileStore, router: router)
                } label: {
                    Text("Try again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.forest)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .onAppear { vm.startFinalisingIfNeeded(profileStore: profileStore, router: router) }
    }
}
