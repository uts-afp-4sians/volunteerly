import SwiftUI
import PhotosUI

struct SignupView: View {
    private enum Field: Hashable {
        case firstName
        case lastName
        case instagram
    }

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var dobSet = false
    @State private var showDOBPicker = false
    @State private var profileItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var instagram = ""
    @FocusState private var focusedField: Field?

    private let totalSteps = 4
    private let currentStep = 1

    private static let monthAbbreviations = [
        "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
        "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
    ]

    private var dobDay: String {
        guard dobSet else { return "--" }
        let d = Calendar.current.component(.day, from: dateOfBirth)
        return String(format: "%02d", d)
    }

    private var dobMonth: String {
        guard dobSet else { return "---" }
        let m = Calendar.current.component(.month, from: dateOfBirth)
        return Self.monthAbbreviations[m - 1]
    }

    private var dobYear: String {
        guard dobSet else { return "----" }
        return String(Calendar.current.component(.year, from: dateOfBirth))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ProgressBar(progress: Double(currentStep) / Double(totalSteps))

                Text("Let's introduce\nyourself")
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)

                nameRow
                dateOfBirthField
                profilePictureRow
                instagramField

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
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
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
        fieldColumn(label: "Date of birth (DD/MM/YYYY)", required: true) {
            Button {
                focusedField = nil
                showDOBPicker = true
            } label: {
                HStack(spacing: 8) {
                    dobBox(dobDay)
                    dobBox(dobMonth)
                    dobBox(dobYear)
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

                    Button {
                        dobSet = true
                        showDOBPicker = false
                    } label: {
                        Text("Done")
                            .font(.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.forest)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func dobBox(_ value: String) -> some View {
        Text(value)
            .font(.bodyText)
            .foregroundStyle(dobSet ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    // MARK: Profile picture

    private var profilePictureRow: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $profileItem, matching: .images) {
                profileCircle
                    .frame(width: 110, height: 110)
            }
            .onChange(of: profileItem) { _, newItem in
                Task { profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
            }

            Text("Let's put a face to your name - upload a profile picture here!")
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var profileCircle: some View {
        if let data = profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Color(.systemGray6))
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Instagram

    private var instagramField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instagram")
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            borderedTextField {
                TextField("", text: $instagram)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .instagram)
            }
        }
    }

    // MARK: Next

    private var nextButton: some View {
        NavigationLink(value: AuthRoute.signupForm(SignupBasics(
            firstName: firstName,
            lastName: lastName,
            email: "",
            password: ""
        ))) {
            Text("Next")
                .font(.buttonLabel)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canContinue ? Theme.forest : Theme.forest.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .disabled(!canContinue)
    }

    private var canContinue: Bool {
        !firstName.isEmpty && !lastName.isEmpty && dobSet
    }

    // MARK: Helpers

    private func fieldColumn<Content: View>(label: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                if required {
                    Text("*")
                        .requiredFieldStyle()
                }
            }
            content()
        }
    }

    private func borderedTextField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.bodyText)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

}

#Preview {
    AuthFlowView()
        .environment(AppRouter())
        .environment(UserProfileStore())
}
