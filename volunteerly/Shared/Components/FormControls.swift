import SwiftUI

// Shared signup/form controls derived 1:1 from the Figma design system
// (Color Tokens node 450:751, Typography node 468:751, and the SignupForm
// screens). Use these so every step shares one field/button/label spec instead
// of re-deriving inline styles per screen.

extension View {
    /// Figma input / search "textbox" surface — Black/50 fill, 8pt radius,
    /// 17pt horizontal inset, no border.
    func formFieldSurface(height: CGFloat = 54) -> some View {
        self
            .font(.bodyText)
            .padding(.horizontal, 17)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Figma primary button label — Brand/400 fill (Black/100 when disabled),
    /// 50pt-tall capsule, 14 Bold on-brand text. Apply to the button's `Text`.
    func primaryActionButtonStyle(enabled: Bool = true) -> some View {
        self
            .font(.buttonLabel)
            .foregroundStyle(enabled ? Theme.onBrand : Theme.placeholder)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(enabled ? Theme.brandPrimary : Theme.divider)
            .clipShape(Capsule())
    }
}

/// Figma field label — Body 16 on Icon/Primary, with an optional required `*`.
struct FieldLabel: View {
    let text: String
    var required: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Text(text)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            if required { Text("*").requiredFieldStyle() }
        }
    }
}
