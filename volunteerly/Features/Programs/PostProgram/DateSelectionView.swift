import SwiftUI

/// Date picker bottom sheet — the calendar half of the Starts/Ends row
/// (Figma node 358:967). Tapping a row's **Date** chip presents this.
///
/// The frame is the native SwiftUI `DatePicker` in `.graphical` style: the bold
/// month label with a disclosure chevron, the `‹ ›` month arrows, the weekday
/// header row and the circular selected-day are all stock system UI. We keep it
/// native (rather than hand-rolling a calendar) so it tracks iOS behaviour, and
/// tint the selection brand-green to match the mock. Chrome (grey drag handle,
/// centred 24pt title, green Save) matches the Figma sheet (389:1157).
struct DateSelectionView: View {
    @Binding var date: Date
    /// Lower bound for selection (used by the "Ends" sheet to stay >= start).
    var minimumDate: Date? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 12)

            Text("Calendar View")
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 8)

            Group {
                if let minimumDate {
                    DatePicker(
                        "",
                        selection: $date,
                        in: minimumDate...,
                        displayedComponents: [.date]
                    )
                } else {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                }
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
            // Figma shows a brand-green filled selection circle.
            .tint(Color.brand)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            confirmButton
        }
        .background(Color.white)
    }

    // MARK: - Chrome

    /// Custom grey drag handle (Figma 358:984 — #F5F5F5, 80×6).
    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemGray6))
            .frame(width: 80, height: 6)
    }

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Save")
                .font(.buttonLabel)
                .foregroundStyle(Color.onBrand)
                .frame(maxWidth: .infinity)
                .frame(height: 53)
                .background(Color.brand, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            DateSelectionView(date: .constant(Date()))
                .presentationDetents([.height(560)])
                .presentationDragIndicator(.hidden)
        }
}
