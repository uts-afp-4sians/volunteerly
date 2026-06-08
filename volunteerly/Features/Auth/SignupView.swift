import SwiftUI

struct SignupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var dobSet = false
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var location = ""

    @FocusState private var passwordFocused: Bool
    @FocusState private var locationFocused: Bool

    private let totalSteps = 4
    private let currentStep = 1

    private static let citySuggestions: [String] = [
        "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide",
        "Gold Coast", "Canberra", "Newcastle", "Wollongong", "Hobart",
        "Darwin", "Geelong", "Cairns", "Townsville",
        "Auckland", "Wellington", "Christchurch",
        "London", "Manchester", "Edinburgh", "Dublin",
        "New York", "Los Angeles", "San Francisco", "Chicago",
        "Toronto", "Vancouver", "Montreal",
        "Paris", "Lyon", "Marseille",
        "Berlin", "Munich", "Hamburg",
        "Madrid", "Barcelona", "Lisbon",
        "Rome", "Milan",
        "Amsterdam", "Brussels", "Zurich", "Vienna",
        "Singapore", "Hong Kong", "Tokyo", "Seoul",
    ]

    private var locationMatches: [String] {
        let query = location.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        let matches = Self.citySuggestions.filter { $0.lowercased().hasPrefix(lower) }
        if matches.count == 1, matches[0].caseInsensitiveCompare(query) == .orderedSame {
            return []
        }
        return Array(matches.prefix(5))
    }

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
            VStack(alignment: .leading, spacing: 8) {
                pillField(icon: "location") {
                    TextField("City", text: $location)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()
                        .focused($locationFocused)
                }

                if locationFocused && !locationMatches.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(locationMatches.enumerated()), id: \.element) { index, city in
                            Button {
                                location = city
                                locationFocused = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle")
                                        .foregroundStyle(Theme.textSecondary)
                                    Text(city)
                                        .font(.body)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < locationMatches.count - 1 {
                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 1)
                                    .padding(.horizontal, 18)
                            }
                        }
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: Continue

    private var continueButton: some View {
        NavigationLink(value: AuthRoute.signupForm(SignupBasics(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password
        ))) {
            Text("Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canContinue ? Theme.forest : Theme.forest.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(!canContinue)
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
        .environment(UserProfileStore())
}
