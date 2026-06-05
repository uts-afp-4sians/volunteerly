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
    /// Invoked when the trailing mic button is tapped (voice search). Optional —
    /// the mic is hidden when `nil`.
    var onMicTap: (() -> Void)?

    private let backgroundColor = Color(red: 0.959, green: 0.959, blue: 0.959) // #F5F5F5
    private let cornerRadius: CGFloat = 20

    init(
        text: Binding<String>,
        placeholder: String = "Search",
        onMicTap: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onMicTap = onMicTap
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

            if let onMicTap {
                Button(action: onMicTap) {
                    Image(systemName: "mic")
                        .font(.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
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
                SearchBar(text: $empty, onMicTap: {})
                SearchBar(text: $filled, onMicTap: {})
                SearchBar(text: $empty) // without mic
            }
            .padding()
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
