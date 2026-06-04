import SwiftUI

/// A custom label/chip component conforming to the design system.
///
/// - Shape: Capsule (pill-shaped)
/// - Font: `.buttonLabel` (SF Pro Regular 14)
/// - Selected state: filled with `#DDDDDD` (87% opacity)
/// - Unselected state: outlined with `Color.brandLight` (#C1D09A)
struct Label: View {
    let text: String
    let isSelected: Bool
    var action: (() -> Void)? = nil
    
    // Visual customization overrides
    var height: CGFloat? = nil

    private let selectedBgColor = Color(red: 0.867, green: 0.867, blue: 0.867).opacity(0.87) // #DDDDDD 87%
    private let strokeColor = Color.brandLight

    var body: some View {
        let labelContent = Text(text)
            .font(.buttonLabel)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(isSelected ? selectedBgColor : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : strokeColor, lineWidth: 1)
            )

        if let action {
            Button(action: action) {
                labelContent
            }
            .buttonStyle(.plain)
        } else {
            labelContent
        }
    }
}

#Preview("Label states") {
    struct Demo: View {
        @State private var firstSelected = false
        @State private var secondSelected = true
        
        var body: some View {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Unselected (Static)").font(.labelItalic)
                        Label(text: "Unselected Label", isSelected: false)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Selected (Static)").font(.labelItalic)
                        Label(text: "Selected Label", isSelected: true)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interactive Labels (Click to toggle)").font(.labelItalic)
                    HStack(spacing: 12) {
                        Label(text: "Environment", isSelected: firstSelected) {
                            firstSelected.toggle()
                        }
                        
                        Label(text: "Community Service", isSelected: secondSelected) {
                            secondSelected.toggle()
                        }
                    }
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
