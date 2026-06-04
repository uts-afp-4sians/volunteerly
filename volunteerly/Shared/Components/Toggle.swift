import SwiftUI

/// The design-system **Toggle**: a 40×40 white knob inside a 30px-rounded track,
/// inset 15px from the track edge. No label (toggles carry no text).
///
/// - First state  — grey track, knob to the left.
/// - Second state — brand-green track, knob to the right.
struct Toggle: View {
    @Binding var isOn: Bool

    private let trackWidth: CGFloat = 102
    private let trackHeight: CGFloat = 53
    private let knobSize: CGFloat = 40
    private let inset: CGFloat = 10

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(isOn ? Color.brand : Color(red: 0.87, green: 0.87, blue: 0.87))
                .frame(width: trackWidth, height: trackHeight)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: knobSize, height: knobSize)
                        .padding(.horizontal, inset)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isOn)
        .accessibilityRepresentation {
            SwiftUI.Toggle("", isOn: $isOn)
        }
    }
}

#Preview("Toggle states") {
    struct Demo: View {
        @State private var first = false
        @State private var second = true
        var body: some View {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Toggle(isOn: $first)
                    Text("First state").font(.labelItalic)
                }
                VStack(spacing: 6) {
                    Toggle(isOn: $second)
                    Text("Second state").font(.labelItalic)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
