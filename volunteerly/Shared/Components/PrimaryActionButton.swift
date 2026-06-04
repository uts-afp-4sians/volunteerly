import SwiftUI

/// The design-system **Primary Action** button.
///
/// Per the buttons spec: 30px rounded corners, SF Pro Regular 14 label in
/// `#f5f5f5` (`Color.onBrand`) with 15px padding on every side.
/// - Active  — brand green (`#7E924E`) fill.
/// - Focus   — brand green fill with a brand-green ring just outside the pill.
/// - Pressed — brand-dark (`#4C5E24`) fill.
struct PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PrimaryActionButtonStyle())
    }
}

/// Reusable style so any `Button` can adopt the primary-action look.
/// `forcedPressed` / `forcedFocused` exist only to render the states in previews;
/// leave them `nil` for real, interaction-driven behaviour.
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var environmentFocused
    var forcedPressed: Bool? = nil
    var forcedFocused: Bool? = nil

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = forcedPressed ?? configuration.isPressed
        let isFocused = forcedFocused ?? environmentFocused

        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(Color.onBrand)
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(isPressed ? Color.brandDark : Color.brand)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.brand, lineWidth: isFocused ? 2 : 0)
                    .padding(-4)
            )
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

#Preview("Primary Action states") {
    VStack(spacing: 24) {
        VStack(spacing: 6) {
            Button("Active state") {}
                .buttonStyle(PrimaryActionButtonStyle())
            Text("Active").font(.labelItalic)
        }
        VStack(spacing: 6) {
            Button("Focus state") {}
                .buttonStyle(PrimaryActionButtonStyle(forcedFocused: true))
            Text("Focus").font(.labelItalic)
        }
        VStack(spacing: 6) {
            Button("Pressed state") {}
                .buttonStyle(PrimaryActionButtonStyle(forcedPressed: true))
            Text("Pressed").font(.labelItalic)
        }
    }
    .padding(40)
    .background(Color.pageBackground)
}
