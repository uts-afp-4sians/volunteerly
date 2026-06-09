import SwiftUI

/// Event-reoccurrence picker bottom sheet (Figma node 329:1821).
///
/// A centered "Event reoccurence" title over a stack of full-width brand-green
/// pills, each carrying a radio indicator (filled = selected, ring =
/// unselected) and a white label, followed by an italic helper caption. It is
/// presented as a bare sheet with a custom blue drag handle.
struct RepeatSelectionView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) private var dismiss

    private let options = ["Never", "Every week", "Every month", "Custom"]

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            Text("Event reoccurence")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(spacing: 14) {
                ForEach(options, id: \.self) { option in
                    optionPill(option)
                }
            }
            .padding(.horizontal, 20)

            Text("Choose how often this program should hold repeated in person meetings/activities")
                .font(.system(size: 16, weight: .regular).italic())
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .background(Color.white)
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondaryBlue)
            .frame(width: 56, height: 6)
    }

    // MARK: - Option pill

    private func optionPill(_ option: String) -> some View {
        let isSelected = selectedRepeat == option
        return Button {
            selectedRepeat = option
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { dismiss() }
        } label: {
            HStack(spacing: 16) {
                radio(isSelected: isSelected)
                Text(option)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.onBrand)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brand)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func radio(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                Circle().fill(Color.onBrand)
            } else {
                Circle().strokeBorder(Color.onBrand, lineWidth: 3)
            }
        }
        .frame(width: 22, height: 22)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            RepeatSelectionView(selectedRepeat: .constant("Never"))
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
        }
}
