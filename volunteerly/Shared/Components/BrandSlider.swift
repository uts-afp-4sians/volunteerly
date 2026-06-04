import SwiftUI

/// Continuous slider matching the Figma "Additional filters" design:
/// a 6pt rounded track with a blue fill and a wide white pill knob.
struct BrandSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let trackHeight: CGFloat = 6
    private let knobWidth: CGFloat = 38
    private let knobHeight: CGFloat = 24
    private let fillColor = Color(red: 0, green: 0x88 / 255, blue: 1) // #0088FF

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - knobWidth, 1)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let knobX = min(max(fraction, 0), 1) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: knobX + knobWidth / 2, height: trackHeight)

                RoundedRectangle(cornerRadius: knobHeight / 2, style: .continuous)
                    .fill(Color(.systemBackground))
                    .frame(width: knobWidth, height: knobHeight)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: knobX)
            }
            .frame(height: knobHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = min(max(gesture.location.x - knobWidth / 2, 0), usable)
                        value = range.lowerBound + (x / usable) * span
                    }
            )
        }
        .frame(height: knobHeight)
    }
}

#Preview {
    struct Demo: View {
        @State private var value = 25.0
        var body: some View {
            BrandSlider(value: $value, range: 0...50)
                .padding()
        }
    }
    return Demo()
}
