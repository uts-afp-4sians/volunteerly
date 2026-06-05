import SwiftUI
import PhotosUI

struct SignupView: View {
    @Environment(AppRouter.self) private var router

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var dobSet = false
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var location = ""
    @State private var profileItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @FocusState private var passwordFocused: Bool

    private let totalSteps = 4
    private let currentStep = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                titleBlock
                nameRow
                dateOfBirthField
                emailField
                passwordField
                locationField
                optionalDivider
                profilePictureSection
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(height: 8)
                continueButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    // MARK: Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressBar(progress: Double(currentStep) / Double(totalSteps))
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Let's get started")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Tell us the basics.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Fields

    private var nameRow: some View {
        HStack(spacing: 12) {
            labeled("First name *") {
                pillField(icon: "person") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                }
            }
            labeled("Last name *") {
                pillField(icon: "person") {
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                }
            }
        }
    }

    private var dateOfBirthField: some View {
        labeled("Date of birth *") {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.textSecondary)
                if dobSet {
                    Text(dateOfBirth.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text("YYYY-MM-DD")
                        .foregroundStyle(Theme.placeholder)
                }
                Spacer(minLength: 0)
                DatePicker(
                    "",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(Theme.forest)
                .onChange(of: dateOfBirth) { _, _ in dobSet = true }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            labeled("Email *") {
                pillField(icon: "envelope") {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            Text("This will be your login username")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
        }
    }

    private var passwordField: some View {
        labeled("Password *") {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(Theme.textSecondary)
                if showPassword {
                    TextField("Password (min 6 characters)", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($passwordFocused)
                } else {
                    SecureField("Password (min 6 characters)", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($passwordFocused)
                }
                Button {
                    let wasFocused = passwordFocused
                    showPassword.toggle()
                    if wasFocused {
                        DispatchQueue.main.async { passwordFocused = true }
                    }
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private var locationField: some View {
        labeled("Location *") {
            pillField(icon: "location") {
                TextField("City", text: $location)
                    .textContentType(.addressCity)
            }
        }
    }

    private var optionalDivider: some View {
        HStack(spacing: 12) {
            line
            Text("Optional")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            line
        }
        .padding(.vertical, 4)
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    private var profilePictureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile picture")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            PhotosPicker(selection: $profileItem, matching: .images) {
                HStack(spacing: 14) {
                    profileThumb
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileImageData == nil ? "Add a photo" : "Change photo")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text("JPG or PNG, square works best")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .onChange(of: profileItem) { _, newItem in
                Task {
                    profileImageData = try? await newItem?.loadTransferable(type: Data.self)
                }
            }
        }
    }

    @ViewBuilder
    private var profileThumb: some View {
        if let data = profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Theme.background)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                Image(systemName: "camera")
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: Continue

    private var continueButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue").font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(canContinue ? Theme.forest : Theme.forest.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(!canContinue || isSubmitting)
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await AuthService.shared.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            router.route = .main
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var canContinue: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        dobSet &&
        email.contains("@") &&
        password.count >= 6 &&
        !location.isEmpty
    }

    // MARK: Field helpers

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
    }

    private func pillField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.textSecondary)
            content()
                .font(.body)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Theme placeholder helper

private extension Theme {
    static var placeholder: Color { Theme.textSecondary.opacity(0.7) }
}

#Preview {
    AuthFlowView()
        .environment(AppRouter())
}
