import SwiftUI

struct DateSelectionView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    @Environment(\.dismiss) var dismiss

    var durationText: String {
        if isAllDay {
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return days <= 0 ? "1 day" : "\(days + 1) days"
        } else {
            let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
            if minutes < 60 {
                return "\(minutes) minutes"
            } else {
                let hours = Double(minutes) / 60.0
                return String(format: "%.1f hours", hours)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.bodyStrong)
                        .foregroundStyle(Theme.textPrimary)
                    Text(durationText)
                        .font(.pageTitle)
                        .foregroundStyle(Color.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                VStack(spacing: 20) {
                    HStack {
                        Text("All-Day Event")
                            .font(.bodyText)
                        Spacer()
                        Toggle(isOn: $isAllDay)
                    }
                    
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Starts")
                            .font(.buttonLabel)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: $startDate,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.brand)
                    }
                    
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ends")
                            .font(.buttonLabel)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.brand)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.bodyStrong)
                        .foregroundStyle(Color.onBrand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Select Date & Time")
        .navigationBarTitleDisplayMode(.inline)
    }
}
