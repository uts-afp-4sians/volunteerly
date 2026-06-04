import SwiftUI

/// The design-system **Radio** button: a brand-green pill with a 20×20 indicator
/// 15px in from the leading edge and an SF Pro Regular 14 label in `#f5f5f5`.
///
/// - No selection — solid white indicator.
/// - Selected     — hollow white ring.
///
/// Pill: 20px rounded corners; label padded 15px on all sides.
struct RadioButton: View {
    let title: String
    @Binding var isSelected: Bool

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 0) {
                indicator
                    .frame(width: 20, height: 20)
                    .padding(.leading, 15)

                Text(title)
                    .font(.buttonLabel)
                    .foregroundStyle(Color.onBrand)
                    .padding(15)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.brand)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var indicator: some View {
        if isSelected {
            Circle().strokeBorder(Color.onBrand, lineWidth: 4)
        } else {
            Circle().fill(Color.onBrand)
        }
    }
}

#Preview("Radio states") {
    struct Demo: View {
        @State private var off = false
        @State private var on = true
        var body: some View {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    RadioButton(title: "No selection state", isSelected: $off)
                    Text("No selection").font(.labelItalic)
                }
                VStack(spacing: 6) {
                    RadioButton(title: "Selected state", isSelected: $on)
                    Text("Selected").font(.labelItalic)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
