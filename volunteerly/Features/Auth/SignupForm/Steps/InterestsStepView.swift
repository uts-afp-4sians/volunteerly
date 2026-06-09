import SwiftUI

struct InterestsStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What are your interests?")
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Pick at least two of the following")
                    .font(.labelItalic)
                    .foregroundStyle(Theme.textSecondary)
            }

            if vm.isLoadingInterests {
                ProgressView()
                    .tint(Theme.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
            } else {
                FlowLayout(spacing: 10, lineSpacing: 12) {
                    ForEach(vm.interestCatalog) { keyword in
                        interestChip(
                            emoji: UserProfileStore.emoji(for: keyword.name),
                            name: keyword.name
                        )
                    }
                }
            }
        }
        .task { await vm.loadInterests() }
    }

    private func interestChip(emoji: String, name: String) -> some View {
        let selected = vm.selectedInterests.contains(name)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                if selected {
                    vm.selectedInterests.remove(name)
                } else {
                    vm.selectedInterests.insert(name)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(name).font(.body)
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? Theme.forest : Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
