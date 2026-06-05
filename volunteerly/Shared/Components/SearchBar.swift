import SwiftUI

/// A pill-shaped search field from Figma `group-4-prototype` (node 226:277):
/// a leading magnifying glass, a free-text field, and a trailing mic button.
///
/// - Background: `#F5F5F5`
/// - Corner radius: 20
/// - Font: `.bodyText` (16, regular) for both content and placeholder
/// - 8px gap between the magnifying glass and the search field
/// - 8px padding between the elements and the outer frame
/// - The search field expands to fill the bar, pushing the mic to the trailing
///   edge (the Figma "221px padding between search and mic" is this flexible gap).
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"
    /// Whether to show the trailing mic for voice search. Hidden when `false`.
    var showsMic: Bool

    private let backgroundColor = Color(red: 0.959, green: 0.959, blue: 0.959) // #F5F5F5
    private let cornerRadius: CGFloat = 20

    init(
        text: Binding<String>,
        placeholder: String = "Search",
        showsMic: Bool = true
    ) {
        self._text = text
        self.placeholder = placeholder
        self.showsMic = showsMic
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

            if showsMic {
                MicButton(text: $text, tint: Theme.textSecondary)
                    .font(.bodyText)
            }
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
                SearchBar(text: $empty, showsMic: false) // without mic
            }
            .padding()
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
