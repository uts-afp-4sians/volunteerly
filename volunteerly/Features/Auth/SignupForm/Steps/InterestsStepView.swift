import SwiftUI

struct InterestsStepView: View {
    @Bindable var vm: SignupFormViewModel
    @State private var showAddInterest = false
    @State private var newInterest = ""

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
                    ForEach(customInterests, id: \.self) { name in
                        interestChip(emoji: "🏷️", name: name)
                    }
                    addMoreChip
                }
            }
        }
        .task { await vm.loadInterests() }
        .alert("Add an interest", isPresented: $showAddInterest) {
            TextField("e.g. Reading, Hiking", text: $newInterest)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newInterest = "" }
            Button("Add") { addCustomInterest() }
        } message: {
            Text("Type any interest you'd like to volunteer for.")
        }
    }

    /// Selected interests that aren't in the catalog — i.e. user-typed ones.
    private var customInterests: [String] {
        let catalogNames = Set(vm.interestCatalog.map(\.name))
        return vm.selectedInterests.subtracting(catalogNames).sorted()
    }

    private var addMoreChip: some View {
        Button {
            showAddInterest = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add more").font(.buttonLabel)
            }
            .foregroundStyle(Theme.forest)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.forest.opacity(0.08))
            .overlay(
                Capsule()
                    .stroke(Theme.forest, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func addCustomInterest() {
        let trimmed = newInterest.trimmingCharacters(in: .whitespacesAndNewlines)
        newInterest = ""
        guard !trimmed.isEmpty else { return }
        let alreadyPicked = vm.selectedInterests.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        let inCatalog = vm.interestCatalog.contains {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !alreadyPicked, !inCatalog else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            _ = vm.selectedInterests.insert(trimmed)
        }
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
                Text(name).font(.buttonLabel)
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? Theme.forestLight : Color(.systemGray5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
