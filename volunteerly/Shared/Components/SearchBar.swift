import SwiftUI

/// A pill-shaped search field from Figma `group-4-prototype` (node 226:277):
/// a leading magnifying glass and a free-text field.
///
/// - Background: `#F5F5F5`
/// - Corner radius: 20
/// - Font: `.bodyText` (16, regular) for both content and placeholder
/// - 8px gap between the magnifying glass and the search field
/// - 8px padding between the elements and the outer frame
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    private let backgroundColor = Color(red: 0.959, green: 0.959, blue: 0.959) // #F5F5F5
    private let cornerRadius: CGFloat = 20

    init(
        text: Binding<String>,
        placeholder: String = "Search"
    ) {
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)

            TextField(placeholder, text: $text)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .textFieldStyle(.plain)
                .submitLabel(.search)
        }
        .padding(8)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview("SearchBar states") {
    struct Demo: View {
        @State private var empty = ""
        @State private var filled = "Beach cleanup"

        var body: some View {
            VStack(spacing: 24) {
                SearchBar(text: $empty)
                SearchBar(text: $filled)
            }
            .padding()
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
