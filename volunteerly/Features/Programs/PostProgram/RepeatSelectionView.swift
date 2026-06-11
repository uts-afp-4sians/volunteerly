import SwiftUI

/// Event-recurrence picker bottom sheet (Figma node 329:1820).
///
/// A centered "Event recurrence" title over a stack of single-select DS
/// `RadioButton` pills (selected = brand-green, others = white outlined),
/// followed by an italic helper caption. It is presented as a bare sheet with a
/// custom grey drag handle (Figma 329:1820).
///
/// This sheet is the single control for the program's `commitment_frequency`:
/// "Never" clears it, "Every week" → `.weekly`, "Every month" → `.monthly`.
/// (Figma's "Custom" row is omitted — the backend has no representation for it
/// and there's no custom-rule builder yet; re-add it once one exists.)
struct RepeatSelectionView: View {
    @Binding var selection: CommitmentFrequency?
    @Environment(\.dismiss) private var dismiss

    /// Sheet rows in display order, paired with the value each persists. Shared
    /// with the form's "Repeat" row (`label(for:)`) so the two never drift.
    static let choices: [(label: String, value: CommitmentFrequency?)] = [
        ("Never", nil),
        ("Every week", .weekly),
        ("Every month", .monthly),
    ]

    /// Display label for a stored frequency, used by the collapsed "Repeat" row.
    static func label(for value: CommitmentFrequency?) -> String {
        choices.first { $0.value == value }?.label ?? "Never"
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Text("Event recurrence")
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(spacing: 16) {
                ForEach(Self.choices, id: \.label) { choice in
                    RadioButton(title: choice.label, isSelected: selection == choice.value) {
                        selection = choice.value
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { dismiss() }
                    }
                }
            }
            .padding(.horizontal, 20)

            Text("Choose how often this program should hold repeated in person meetings/activities")
                .font(.labelItalic)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        // Figma leaves ~48pt between the caption and the home indicator; the
        // Spacer only absorbs rounding slack, the detent must stay near-fitted.
        .padding(.bottom, 48)
        .background(Color.white)
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemGray6))
            .frame(width: 80, height: 6)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            RepeatSelectionView(selection: .constant(nil))
                .presentationDetents([.height(450)])
                .presentationDragIndicator(.hidden)
        }
}
