import SwiftUI

/// Date/time picker bottom sheet matching the Figma calendar design.
///
/// The Figma frame is the native SwiftUI `DatePicker` in `.graphical` style:
/// the bold month label with a disclosure chevron, the `‹ ›` month arrows, the
/// weekday header row and the circular selected-day are all stock system UI.
/// We keep it native (rather than hand-rolling a calendar) so it tracks iOS
/// behaviour, and style the selection + Confirm button to match the mock.
struct DateSelectionView: View {
    let title: String
    @Binding var date: Date
    @Binding var isAllDay: Bool
    /// Lower bound for selection (used by the "Ends" sheet to stay >= start).
    var minimumDate: Date? = nil
    @Environment(\.dismiss) private var dismiss

    private var components: DatePickerComponents {
        isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(title)
                        .font(.sectionHeader)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 8)

                    HStack {
                        Text("All-Day Event")
                            .font(.bodyText)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Toggle(isOn: $isAllDay)
                    }

                    Group {
                        if let minimumDate {
                            DatePicker(
                                "",
                                selection: $date,
                                in: minimumDate...,
                                displayedComponents: components
                            )
                        } else {
                            DatePicker(
                                "",
                                selection: $date,
                                displayedComponents: components
                            )
                        }
                    }
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    // Figma shows a black filled selection circle; textPrimary is
                    // the design token closest to that (not a hardcoded hex).
                    .tint(Theme.textPrimary)
                }
                .padding(.horizontal, 20)
            }

            Button {
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}

#Preview {
    DateSelectionView(
        title: "Starts",
        date: .constant(Date()),
        isAllDay: .constant(false)
    )
}
