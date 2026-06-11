import SwiftUI

/// Bottom sheet for choosing interests: every catalogue interest is shown as a
/// toggleable chip, and "Save" writes the selection back to the profile.
struct InterestPickerSheet: View {
    /// The interests currently on the profile, used to seed the selection.
    let selected: [UserProfileStore.Interest]
    /// Called with the full chosen set when the user taps Save.
    let onSave: ([UserProfileStore.Interest]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedNames: Set<String>

    init(selected: [UserProfileStore.Interest], onSave: @escaping ([UserProfileStore.Interest]) -> Void) {
        self.selected = selected
        self.onSave = onSave
        _selectedNames = State(initialValue: Set(selected.map(\.name)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                FlowLayout(spacing: 10, lineSpacing: 12) {
                    ForEach(UserProfileStore.interestCatalog, id: \.name) { item in
                        chip(emoji: item.emoji, name: item.name)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            saveButton
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("My interests")
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)
            Text("Tap to select the causes you care about")
                .font(.buttonLabel)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func chip(emoji: String, name: String) -> some View {
        let isSelected = selectedNames.contains(name)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                if isSelected { selectedNames.remove(name) } else { selectedNames.insert(name) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(name).font(.bodyText)
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.forest.opacity(0.12) : Color(.systemGray6), in: Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Theme.forest : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(UserProfileStore.blurb(for: name))
    }

    private var saveButton: some View {
        Button {
            let interests = UserProfileStore.interestCatalog
                .filter { selectedNames.contains($0.name) }
                .map { UserProfileStore.Interest(emoji: $0.emoji, name: $0.name) }
            onSave(interests)
            dismiss()
        } label: {
            Text("Save")
                .font(.bodyStrong)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.forest)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        InterestPickerSheet(
            selected: [UserProfileStore.Interest(emoji: "🐾", name: "Animals")],
            onSave: { _ in }
        )
    }
}
