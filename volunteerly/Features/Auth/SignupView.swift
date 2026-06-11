import SwiftUI

/// Step 1 of the 6-step signup flow — "Let's introduce yourself" (Figma
/// Introduction Screen, node 209:629). Collects first/last name + date of
/// birth only; photo + Instagram move to step 2 inside the SignupForm.
struct SignupView: View {
    private enum Field: Hashable {
        case firstName
        case lastName
    }

    // Optional — see WelcomeView: an animated route switch can re-evaluate this
    // view outside the `.environment(router)` scope.
    @Environment(AppRouter.self) private var router: AppRouter?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var dobSet = false
    @State private var showDOBPicker = false
    @FocusState private var focusedField: Field?

    // 6-step signup flow (this intro screen is step 1; the SignupForm covers 2–6).
    // Keep the denominator aligned with SignupFormViewModel.totalSteps so the
    // ProgressBar advances consistently across the whole flow.
    private let totalSteps = 6
    private let currentStep = 1

    private var dobDay: String {
        guard dobSet else { return "DD" }
        return String(format: "%02d", Calendar.current.component(.day, from: dateOfBirth))
    }

    private var dobMonth: String {
        guard dobSet else { return "MM" }
        return String(format: "%02d", Calendar.current.component(.month, from: dateOfBirth))
    }

    private var dobYear: String {
        guard dobSet else { return "YYYY" }
        return String(Calendar.current.component(.year, from: dateOfBirth))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ProgressBar(progress: Double(currentStep) / Double(totalSteps))

                Text("Let's introduce\nyourself")
                    .largeTitleStyle()

                nameRow
                dateOfBirthField

                Spacer().frame(height: 8)
                nextButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router?.route = .home
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Back to home")
            }
        }
    }

    // MARK: Name row

    private var nameRow: some View {
        HStack(spacing: 12) {
            fieldColumn(label: "First name", required: true) {
                borderedTextField {
                    TextField("", text: $firstName)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .firstName)
                }
            }
            fieldColumn(label: "Last name", required: true) {
                borderedTextField {
                    TextField("", text: $lastName)
                        .textContentType(.familyName)
                        .focused($focusedField, equals: .lastName)
                }
            }
        }
    }

    // MARK: Date of birth

    private var dateOfBirthField: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Date of birth", required: true)
            Button {
                focusedField = nil
                showDOBPicker = true
            } label: {
                HStack(spacing: 12) {
                    dobColumn(value: dobDay, caption: "Day")
                    dobColumn(value: dobMonth, caption: "Month")
                    dobColumn(value: dobYear, caption: "Year")
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDOBPicker, onDismiss: {
                focusedField = nil
            }) {
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: $dateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.forest)
                    .onChange(of: dateOfBirth) { _, _ in dobSet = true }
                    .padding(.horizontal, 8)
                    .padding(.top, 24)

                    Button {
                        dobSet = true
                        showDOBPicker = false
                    } label: {
                        Text("Done")
                            .primaryActionButtonStyle()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func dobColumn(value: String, caption: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.bodyText)
                .foregroundStyle(dobSet ? Theme.textPrimary : Theme.placeholder)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(caption)
                .font(.captionText)
                .foregroundStyle(Theme.placeholder)
        }
    }

    // MARK: Next

    private var nextButton: some View {
        NavigationLink(value: AuthRoute.signupForm(SignupBasics(
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dobSet ? dateOfBirth : nil
        ))) {
            Text("Next")
                .primaryActionButtonStyle(enabled: canContinue)
        }
        .disabled(!canContinue)
    }

    private var canContinue: Bool {
        !firstName.isEmpty && !lastName.isEmpty && dobSet
    }

    // MARK: Helpers

    private func fieldColumn<Content: View>(label: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: label, required: required)
            content()
        }
    }

    private func borderedTextField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().formFieldSurface(height: 48)
    }
}

#Preview {
    AuthFlowView()
        .environment(AppRouter())
        .environment(UserProfileStore())
}
