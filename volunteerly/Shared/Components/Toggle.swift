import SwiftUI

/// The design-system **Toggle**: a white knob inside a fully-rounded track.
/// No label (toggles carry no text).
///
/// - First state  — grey track, knob to the left.
/// - Second state — brand-green track, knob to the right.
///
/// Size defaults to `.medium`, which matches the native iOS switch (51×31).
struct Toggle: View {
    /// Track/knob dimensions for the toggle. `.medium` matches the native switch.
    enum Size {
        case small, medium, large

        var trackWidth: CGFloat {
            switch self {
            case .small: 40
            case .medium: 51
            case .large: 64
            }
        }

        var trackHeight: CGFloat {
            switch self {
            case .small: 24
            case .medium: 31
            case .large: 39
            }
        }

        var knobSize: CGFloat {
            switch self {
            case .small: 20
            case .medium: 27
            case .large: 33
            }
        }

        var inset: CGFloat {
            switch self {
            case .small, .medium: 2
            case .large: 3
            }
        }
    }

    @Binding var isOn: Bool
    var size: Size = .medium

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: size.trackHeight / 2, style: .continuous)
                .fill(isOn ? Color.brand : Color(red: 0.87, green: 0.87, blue: 0.87))
                .frame(width: size.trackWidth, height: size.trackHeight)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: size.knobSize, height: size.knobSize)
                        .padding(.horizontal, size.inset)
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
                HStack(spacing: 16) {
                    Toggle(isOn: $second, size: .small)
                    Toggle(isOn: $second, size: .medium)
                    Toggle(isOn: $second, size: .large)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
