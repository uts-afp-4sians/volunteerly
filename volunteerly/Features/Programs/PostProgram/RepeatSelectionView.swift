import SwiftUI

/// Event-reoccurrence picker bottom sheet (Figma node 329:1820).
///
/// A centered "Event reoccurence" title over a stack of single-select DS
/// `RadioButton` pills (selected = brand-green, others = white outlined),
/// followed by an italic helper caption. It is presented as a bare sheet with a
/// custom grey drag handle (Figma 329:1820).
struct RepeatSelectionView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) private var dismiss

    private let options = ["Never", "Every week", "Every month", "Custom"]

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Text("Event reoccurence")
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    RadioButton(title: option, isSelected: selectedRepeat == option) {
                        selectedRepeat = option
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
            RepeatSelectionView(selectedRepeat: .constant("Never"))
                .presentationDetents([.height(450)])
                .presentationDragIndicator(.hidden)
        }
}
