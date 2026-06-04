import SwiftUI

/// The design-system **Radio** button: a brand-green pill with a 20×20 indicator
/// 15px in from the leading edge and an SF Pro Regular 14 label in `#f5f5f5`.
///
/// - Selected  — solid white indicator (Node 200-482).
/// - Completed — hollow white ring (Node 200-490).
///
/// Pill: height 48px, 20px rounded corners; label padded 15px on all sides.
enum RadioButtonState {
    case selected
    case completed
}

struct RadioButton: View {
    let title: String
    let state: RadioButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        switch state {
        case .selected:
            Circle()
                .fill(Color.onBrand)
        case .completed:
            Circle()
                .strokeBorder(Color.onBrand, lineWidth: 3)
        }
    }
}

#Preview("Radio states") {
    VStack(spacing: 24) {
        VStack(spacing: 6) {
            RadioButton(title: "Selected state", state: .selected) {}
            Text("Selected (Solid white circle)").font(.labelItalic)
        }
        VStack(spacing: 6) {
            RadioButton(title: "Completed state", state: .completed) {}
            Text("Completed (Hollow white ring)").font(.labelItalic)
        }
    }
    .padding(40)
    .background(Color.pageBackground)
}
