import SwiftUI

/// The design-system **Radio** button: a brand-green pill with a 20×20 indicator
/// 15px in from the leading edge and an SF Pro Regular 14 label in `#f5f5f5`.
///
/// - Unselected  — solid white indicator (Node 200-482).
/// - Selected    — hollow white ring (Node 200-490).
///
/// Pill: height 48px, 20px rounded corners; label padded 15px on all sides.
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
                    .padding(.trailing, 15)
                    .padding(.vertical, 15)
                
                Spacer()
            }
            .frame(height: 48)
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
            Circle()
                .strokeBorder(Color.onBrand, lineWidth: 3)
        } else {
            Circle()
                .fill(Color.onBrand)
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
                    RadioButton(title: "Unselected state", isSelected: $off)
                    Text("Unselected (Solid white circle)").font(.labelItalic)
                }
                VStack(spacing: 6) {
                    RadioButton(title: "Selected state", isSelected: $on)
                    Text("Selected (Hollow white ring)").font(.labelItalic)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
