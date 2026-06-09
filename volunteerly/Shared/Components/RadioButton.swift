import SwiftUI

/// The design-system single-select **Radio** pill (Figma `RADIO` component set,
/// node 226-869).
///
/// Selection is parent-controlled — pass `isSelected` and an `action`; the pill
/// renders one of two states:
/// - **Selected**   — brand-green fill, white hollow ring, white label.
/// - **Unselected** — white fill with a dark hairline border, grey hollow ring,
///   primary-text label.
///
/// Geometry: 48px tall, 20px rounded corners; a 20×20 indicator 15px in from the
/// leading edge, then an SF Pro Regular 14 (`buttonLabel`) label.
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                indicator
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.buttonLabel)
                    .foregroundStyle(isSelected ? Color.onBrand : Theme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            shape.fill(Color.brand)
        } else {
            shape
                .fill(Color.white)
                .overlay(shape.strokeBorder(Theme.textPrimary, lineWidth: 1.5))
        }
    }

    /// A hollow ring in both states — white on the selected pill, grey otherwise.
    private var indicator: some View {
        Circle().strokeBorder(isSelected ? Color.onBrand : Color(.systemGray), lineWidth: 3)
    }
}

#Preview("Radio states") {
    struct Demo: View {
        @State private var selected = "Never"
        private let options = ["Never", "Every week", "Every month", "Custom"]
        var body: some View {
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    RadioButton(title: option, isSelected: selected == option) {
                        selected = option
                    }
                }
            }
            .padding(40)
            .background(Color.white)
        }
    }
    return Demo()
}
