import SwiftUI

/// Repeat-frequency picker bottom sheet (Figma node 226:607).
///
/// A grouped, light-blue (`SecondaryBlueTint` / #EFF4FF) list of frequency
/// options with a checkmark on the selected row, a separate "Custom" card, and
/// a helper caption. It carries its own "Repeat / Done" header, so it is
/// presented as a bare sheet (not wrapped in a navigation stack).
struct RepeatSelectionView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) private var dismiss

    private let options = ["Never", "Every Week", "Every Month"]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    optionList
                    customRow
                    Text("Choose how often this program should repeat on your community calendar.")
                        .font(.buttonLabel)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .background(Color.white)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Repeat")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Option list

    private var optionList: some View {
        VStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selectedRepeat = option
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { dismiss() }
                } label: {
                    HStack(spacing: 0) {
                        Text(option)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 12)
                        if selectedRepeat == option {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .padding(16)
                    // Selected row: #031635 @ 5% over the tint (Figma).
                    .background(selectedRepeat == option ? Theme.textPrimary.opacity(0.05) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .background(Color.secondaryBlueTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Custom

    private var customRow: some View {
        Button {
            // TODO: open custom-recurrence screen — no Figma design for it yet.
        } label: {
            HStack(spacing: 0) {
                Text("Custom")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .background(Color.secondaryBlueTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            RepeatSelectionView(selectedRepeat: .constant("Every Week"))
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.hidden)
        }
}
