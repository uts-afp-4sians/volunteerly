import SwiftUI

/// The "Confirm details" filter bottom sheet for the Program List screen.
/// Edits the view model's filter state directly (it's an `@Observable` reference);
/// `onConfirm` re-fetches with the new query string and dismisses.
struct FilterSheet: View {
    @Bindable var viewModel: ProgramListViewModel
    var onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                distanceSection
                teamSizeSection
                frequencySection
                durationSection
                confirmButton
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Sections

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distance").font(.bodyText)
                Spacer()
                Text("\(Int(viewModel.maxDistance.rounded()))km")
                    .font(.labelItalic)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $viewModel.maxDistance, range: viewModel.distanceRange)
        }
    }

    private var teamSizeSection: some View {
        section("Team size preference") {
            FlowLayout(spacing: 12) {
                ForEach(TeamSize.allCases) { size in
                    FilterChip(
                        title: size.label,
                        isSelected: viewModel.selectedTeamSizes.contains(size)
                    ) {
                        toggle(size, in: \.selectedTeamSizes)
                    }
                }
            }
        }
    }

    private var frequencySection: some View {
        section("Commitment frequency") {
            FlowLayout(spacing: 12) {
                ForEach(CommitmentFrequency.allCases) { frequency in
                    FilterChip(
                        title: frequency.label,
                        isSelected: viewModel.selectedFrequencies.contains(frequency)
                    ) {
                        toggle(frequency, in: \.selectedFrequencies)
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        section("Commitment duration(month)") {
            FlowLayout(spacing: 12) {
                ForEach(CommitmentDuration.allCases) { duration in
                    FilterChip(
                        title: duration.label,
                        isSelected: viewModel.selectedDurations.contains(duration)
                    ) {
                        toggle(duration, in: \.selectedDurations)
                    }
                }
            }
        }
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text("Confirm details")
                .font(.buttonLabel)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.bodyText)
            content()
        }
    }

    /// Toggles `element` in the `Set` reached by `keyPath` on the view model.
    private func toggle<Element: Hashable>(
        _ element: Element,
        in keyPath: ReferenceWritableKeyPath<ProgramListViewModel, Set<Element>>
    ) {
        if viewModel[keyPath: keyPath].contains(element) {
            viewModel[keyPath: keyPath].remove(element)
        } else {
            viewModel[keyPath: keyPath].insert(element)
        }
    }
}

// MARK: - Filter chip

/// A selectable pill chip matching the filter sheet (gray when idle, brand-tinted
/// when selected).
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                )
                .overlay(
                    Capsule().strokeBorder(Color.accentColor, lineWidth: isSelected ? 1.5 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return Color(.systemGray3)
        .sheet(isPresented: .constant(true)) {
            FilterSheet(
                viewModel: ProgramListViewModel(httpClient: MockHTTPClient.shared),
                onConfirm: {}
            )
            .presentationDetents([.fraction(0.7)])
        }
}
