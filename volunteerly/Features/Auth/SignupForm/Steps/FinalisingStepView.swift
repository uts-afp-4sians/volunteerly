import SwiftUI

struct FinalisingStepView: View {
    @Bindable var vm: SignupFormViewModel
    let router: AppRouter?

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            if vm.finalisingError == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.6)
                    .tint(Theme.brandPrimary)

                // Figma Loading Screen (node 211:1261) — Title 24 Bold, centred.
                Text("Your teammates are\nwaiting for you...")
                    .titleStyle()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.pageTitle)
                    .foregroundStyle(Color.fieldError)

                VStack(spacing: 8) {
                    Text("Couldn't create your account")
                        .titleStyle()
                    Text(vm.finalisingError ?? "")
                        .bodyStyle()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Button {
                    vm.finalisingError = nil
                    vm.hasStartedFinalising = false
                    vm.startFinalisingIfNeeded(router: router)
                } label: {
                    Text("Try again")
                        .primaryActionButtonStyle()
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .onAppear { vm.startFinalisingIfNeeded(router: router) }
    }
}
