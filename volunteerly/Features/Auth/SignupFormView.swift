import SwiftUI
import PhotosUI

struct SignupFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step = 2
    private let totalSteps = 6

    // Step 2 — Connect socials
    @State private var profileItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var instagram = ""
    @State private var linkedin = ""

    // Step 3 — Interests
    @State private var selectedInterests: Set<String> = []

    private let interests: [(emoji: String, name: String)] = [
        ("🐶", "Animal Care"),
        ("🎨", "Arts & Creativity"),
        ("👥", "Community Building"),
        ("📚", "Education"),
        ("👴", "Elder Care"),
        ("🌱", "Environment"),
        ("🍳", "Food"),
        ("⚽", "Sports"),
        ("🌳", "Outdoors"),
        ("👗", "Fashion"),
        ("✊", "Social Justice"),
        ("🎵", "Music"),
        ("📷", "Photography"),
        ("🛩", "Travel"),
        ("💻", "Technology"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            progressHeader

            ScrollView(showsIndicators: false) {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
            }

            nextButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if step > 2 { step -= 1 } else { dismiss() }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
        .tint(Theme.forest)
    }

    // MARK: Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressBar(progress: Double(step) / Double(totalSteps))
            Text("Step \(step) of \(totalSteps)")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Step switch

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 2: connectSocialsStep
        case 3: interestsStep
        default: comingSoonStep
        }
    }

    private var comingSoonStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step \(step)")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Coming soon")
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Step 2

    private var connectSocialsStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Connect your socials")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            profileUploadRow
            VStack(alignment: .leading, spacing: 20) {
                socialField(label: "Instagram", text: $instagram)
                socialField(label: "LinkedIn",  text: $linkedin)
            }
        }
    }

    private var profileUploadRow: some View {
        PhotosPicker(selection: $profileItem, matching: .images) {
            HStack(spacing: 20) {
                profileCircle
                    .frame(width: 100, height: 100)
                Text("Upload a profile picture")
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
        }
        .onChange(of: profileItem) { _, newItem in
            Task {
                profileImageData = try? await newItem?.loadTransferable(type: Data.self)
            }
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
                Image(systemName: "plus")
                    .font(.title.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func socialField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            TextField("", text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Step 3

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What are your interests?")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(interests, id: \.name) { interest in
                    interestChip(emoji: interest.emoji, name: interest.name)
                }
            }
        }
    }

    private func interestChip(emoji: String, name: String) -> some View {
        let selected = selectedInterests.contains(name)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                if selected {
                    selectedInterests.remove(name)
                } else {
                    selectedInterests.insert(name)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(name)
                    .font(.body)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? Theme.forest.opacity(0.15) : Color(.systemGray6))
            .overlay(
                Capsule()
                    .stroke(selected ? Theme.forest : Color.clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Next

    private var nextButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { advance() }
        } label: {
            Text("Next")
                .font(.headline)
                .foregroundStyle(canAdvance ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canAdvance ? Theme.forest : Theme.border)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .disabled(!canAdvance)
    }

    private var canAdvance: Bool {
        switch step {
        case 2: return true
        case 3: return !selectedInterests.isEmpty
        default: return false
        }
    }

    private func advance() {
        guard step < totalSteps else {
            // TODO: submit signup at final step
            return
        }
        step += 1
    }
}

#Preview {
    NavigationStack { SignupFormView() }
}
