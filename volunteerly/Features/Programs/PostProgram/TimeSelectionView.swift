import SwiftUI

/// Time picker bottom sheet — the time half of the Starts/Ends row
/// (Figma node 329:1550). Tapping a row's **Time** chip presents this.
///
/// Shorter than the calendar sheet: a "Time" header over the native
/// `DatePicker` wheel limited to `.hourAndMinute`. Chrome (grey drag handle,
/// centred 24pt title, green Save) matches the Figma sheet (389:1156).
struct TimeSelectionView: View {
    @Binding var date: Date
    /// Lower bound (used by the "Ends" sheet so the end can't precede the start
    /// on the same day).
    var minimumDate: Date? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 12)

            Text("Time")
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Group {
                if let minimumDate {
                    DatePicker(
                        "",
                        selection: $date,
                        in: minimumDate...,
                        displayedComponents: [.hourAndMinute]
                    )
                } else {
                    DatePicker(
                        "",
                        selection: $date,
                        displayedComponents: [.hourAndMinute]
                    )
                }
            }
            .datePickerStyle(.wheel)
            .labelsHidden()

            Spacer(minLength: 0)

            confirmButton
        }
        .background(Color.white)
    }

    // MARK: - Chrome

    /// Custom grey drag handle (Figma 351:659 — #F5F5F5, 80×6).
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
            TimeSelectionView(date: .constant(Date()))
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
        }
}
