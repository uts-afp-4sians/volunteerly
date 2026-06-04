import SwiftUI

/// Continuous slider matching the Figma design:
/// a 5pt track with a blue fill and a wide off-white pill knob.
struct Slider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let trackHeight: CGFloat = 5
    private let knobWidth: CGFloat = 49
    private let knobHeight: CGFloat = 24
    private let trackInset: CGFloat = 14
    
    private let trackBgColor = Color(red: 0.867, green: 0.867, blue: 0.867) // #DDDDDD
    private let knobBgColor = Color(red: 0.959, green: 0.959, blue: 0.959) // #F5F5F5

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let usable = max(W - knobWidth, 1)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let knobX = min(max(fraction, 0), 1) * usable
            let knobCenterX = knobX + knobWidth / 2

            ZStack(alignment: .leading) {
                // Track Background
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(trackBgColor)
                    .frame(width: max(W - 2 * trackInset, 0), height: trackHeight)
                    .offset(x: trackInset)

                // Track Fill
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(Color.secondaryBlue)
                    .frame(width: max(knobCenterX - trackInset, 0), height: trackHeight)
                    .offset(x: trackInset)

                // Knob
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(knobBgColor)
                    .frame(width: knobWidth, height: knobHeight)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
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

#Preview("Slider states") {
    struct Demo: View {
        @State private var zeroValue = 0.0
        @State private var middleValue = 25.0
        @State private var fullValue = 50.0
        @State private var interactiveValue = 15.0
        
        var body: some View {
            VStack(spacing: 35) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zero state (0%)").font(.labelItalic)
                    Slider(value: $zeroValue, range: 0...50)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sliding state (50%)").font(.labelItalic)
                    Slider(value: $middleValue, range: 0...50)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("100 state (100%)").font(.labelItalic)
                    Slider(value: $fullValue, range: 0...50)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interactive (Value: \(Int(interactiveValue)))").font(.labelItalic)
                    Slider(value: $interactiveValue, range: 0...50)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
