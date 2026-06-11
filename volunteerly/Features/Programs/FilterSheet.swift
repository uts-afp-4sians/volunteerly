import SwiftUI

/// The filter bottom sheet for the Program List screen.
/// Edits the view model's filter state directly (it's an `@Observable` reference);
/// `onConfirm` re-fetches with the new query string and dismisses.
struct FilterSheet: View {
    @Bindable var viewModel: ProgramListViewModel
    var onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                distanceSection
                teamSizeSection
                frequencySection
                durationSection
                confirmButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Distance").font(.bodyStrong)
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
            FlowLayout(spacing: 10) {
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
            FlowLayout(spacing: 10) {
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
        section("Commitment duration (months)") {
            FlowLayout(spacing: 10) {
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
        PrimaryActionButton("Confirm", action: onConfirm)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.bodyStrong)
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
                .font(.bodyText)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.brand : .primary)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    Capsule().fill(isSelected ? Color.brand.opacity(0.12) : Color(.systemGray6))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.brand : Color.clear, lineWidth: 1)
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
            .presentationDetents([.fraction(0.8)])
        }
}
