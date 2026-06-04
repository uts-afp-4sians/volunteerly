import SwiftUI

/// Design-system type scale (SF Pro — the iOS system font).
///
/// Names avoid the built-in `Font` tokens (`body`, `title`, `caption`, …) so
/// there are no redeclarations.
extension Font {
    /// Title of a page or section — SF Pro Bold 36.
    static let pageTitle = Font.system(size: 36, weight: .bold)
    /// Subheading for a page — SF Pro Regular 30.
    static let subheading = Font.system(size: 30, weight: .regular)
    /// Optional additional header — SF Pro Regular 24.
    static let sectionHeader = Font.system(size: 24, weight: .regular)
    /// Emphasised paragraph text (body strong) — SF Pro Bold 16.
    static let bodyStrong = Font.system(size: 16, weight: .bold)
    /// Paragraph text — SF Pro Regular 16.
    static let bodyText = Font.system(size: 16, weight: .regular)
    /// Button text — SF Pro Regular 14.
    static let buttonLabel = Font.system(size: 14, weight: .regular)
    /// Labels and filler content — SF Pro Regular Italic 14.
    static let labelItalic = Font.system(size: 14, weight: .regular).italic()
}

extension Text {
    /// Required user-entered field — body text in red (e.g. with a trailing `*`).
    func requiredFieldStyle() -> some View {
        font(.bodyText).foregroundStyle(Color.fieldError)
    }

    /// Inline link — SF Pro Regular 16, underlined, secondary-light blue (#AFC2DB).
    func linkStyle() -> some View {
        font(.bodyText).underline().foregroundStyle(Color.secondaryBlueLight)
    }
}

#Preview("Type scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Title of Page / Section").font(.pageTitle)
            Text("Subheadings for each page").font(.subheading)
            Text("(Optional) Any additional headers").font(.sectionHeader)
            Text("Any paragraph text that needs emphasis (body strong)").font(.bodyStrong)
            Text("All paragraph text (textual information and content)").font(.bodyText)
            Text("User entered field that needs to be filled in (*)").requiredFieldStyle()
            Text("All links").linkStyle()
            Text("All text in buttons").font(.buttonLabel)
            Text("All additional labels and filler content").font(.labelItalic)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
