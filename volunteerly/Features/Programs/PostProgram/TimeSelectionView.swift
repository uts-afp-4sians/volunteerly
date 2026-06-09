import SwiftUI

/// Time picker bottom sheet — the time half of the Starts/Ends row
/// (Figma node 329:1550). Tapping a row's **Time** chip presents this.
///
/// Shorter than the calendar sheet: a "Time" header over the native
/// `DatePicker` wheel limited to `.hourAndMinute`. Chrome (blue drag handle,
/// centred title, green Confirm) matches the other PostProgram sheets.
struct TimeSelectionView: View {
    let title: String
    @Binding var date: Date
    /// Lower bound (used by the "Ends" sheet so the end can't precede the start
    /// on the same day).
    var minimumDate: Date? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 12)

            Text(title)
                .font(.system(size: 26, weight: .bold))
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

    /// Custom blue drag handle matching the other PostProgram sheets.
    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondaryBlue)
            .frame(width: 56, height: 6)
    }

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Confirm")
                .font(.bodyStrong)
                .foregroundStyle(Color.onBrand)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
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
            TimeSelectionView(title: "Starts", date: .constant(Date()))
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
        }
}
