import SwiftUI

/// A custom multi-line text input field (TextBox) conforming to the design system.
///
/// - Background: `#F5F5F5`
/// - Corner Radius: 8
/// - Padding: 16px horizontal, 12px vertical
/// - Font: `.bodyText` for content, `.labelItalic` for placeholder
struct TextBox: View {
    @Binding var text: String
    let placeholder: String
    var height: CGFloat = 180

    private let backgroundColor = Color(red: 0.959, green: 0.959, blue: 0.959) // #F5F5F5
    private let cornerRadius: CGFloat = 8

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background representation
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
            
            // TextEditor and Placeholder
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.labelItalic)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false) // Let touches pass through to TextEditor
                }
                
                TextEditor(text: $text)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: height)
    }
}

#Preview("TextBox states") {
    struct Demo: View {
        @State private var emptyText = ""
        @State private var filledText = "Here is some user entered text that spans across multiple lines. The text editor handles it gracefully and wraps the lines correctly."
        
        var body: some View {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Empty state").font(.labelItalic)
                    TextBox(
                        text: $emptyText,
                        placeholder: "This text is visible to the user prior to user entry of their own details (see above for formatting)",
                        height: 150
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Filled state").font(.labelItalic)
                    TextBox(
                        text: $filledText,
                        placeholder: "Placeholder...",
                        height: 150
                    )
                }
            }
            .padding()
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
