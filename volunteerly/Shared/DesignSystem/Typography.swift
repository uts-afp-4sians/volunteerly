import SwiftUI

/// Design-system type scale (SF Pro — the iOS system font).
///
/// Single source of truth: Figma "📐 Typography Scale" (node 468:751).
/// `pt == px`, so Figma sizes map 1:1 to SwiftUI point sizes.
///
/// Names avoid the built-in `Font` tokens (`body`, `title`, `caption`, …) so
/// there are no redeclarations.
extension Font {
    // MARK: Figma type scale (roles map 1:1 to the Figma Typography Scale)

    /// Large Title — page top-level title. SF Pro Bold 32. (Figma: Large Title)
    static let pageTitle = Font.system(size: 32, weight: .bold)
    /// Title — section headers. SF Pro Bold 24. (Figma: Title)
    static let sectionTitle = Font.system(size: 24, weight: .bold)
    /// Headline — card titles, emphasised items. SF Pro Semibold 18. (Figma: Headline)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    /// Body — main body text. SF Pro Regular 16. (Figma: Body)
    static let bodyText = Font.system(size: 16, weight: .regular)
    /// Callout — supporting body, secondary info. SF Pro Regular 15. (Figma: Callout)
    static let calloutText = Font.system(size: 15, weight: .regular)
    /// Subhead — meta info, dates, locations. SF Pro Regular 14. (Figma: Subhead)
    static let subheadText = Font.system(size: 14, weight: .regular)
    /// Caption — hints, annotations. SF Pro Regular 12. (Figma: Caption)
    static let captionText = Font.system(size: 12, weight: .regular)

    // MARK: Project-specific styles (no direct Figma scale role)

    /// Subheading for a page — SF Pro Regular 30.
    static let subheading = Font.system(size: 30, weight: .regular)
    /// Optional additional header — SF Pro Regular 24.
    static let sectionHeader = Font.system(size: 24, weight: .regular)
    /// Emphasised paragraph text (body strong) — SF Pro Bold 16.
    static let bodyStrong = Font.system(size: 16, weight: .bold)
    /// Button text — SF Pro Bold 14 (Figma button label is bold).
    static let buttonLabel = Font.system(size: 14, weight: .bold)
    /// Large button text (e.g. Action Sheet action button) — SF Pro Display Regular 20.
    static let actionButtonLabel = Font.system(size: 20, weight: .regular)
    /// Labels and filler content — SF Pro Regular Italic 14.
    static let labelItalic = Font.system(size: 14, weight: .regular).italic()
    /// Glyph inside an `IconButton` (e.g. `+`, `>`) — SF Pro Regular 36.
    static let iconButtonGlyph = Font.system(size: 36, weight: .regular)
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

    // MARK: Figma "Typography Color Pairing" (node 450:751)
    //
    // Each role pairs a type token with its recommended Black/* colour token on
    // a white background. Prefer these over composing `.font` + `.foregroundStyle`
    // by hand so role/colour stay in sync with the design system.

    /// Large Title 32 Bold · Black/900 (#1C1C1C), tracking −0.5.
    func largeTitleStyle() -> some View {
        font(.pageTitle).tracking(-0.5).foregroundStyle(Color.black900)
    }
    /// Title 24 Bold · Black/900 (#1C1C1C), tracking −0.3.
    func titleStyle() -> some View {
        font(.sectionTitle).tracking(-0.3).foregroundStyle(Color.black900)
    }
    /// Headline 18 Semibold · Black/700 (#4C4C4C).
    func headlineStyle() -> some View {
        font(.cardTitle).foregroundStyle(Color.black700)
    }
    /// Body 16 Regular · Black/700 (#4C4C4C).
    func bodyStyle() -> some View {
        font(.bodyText).foregroundStyle(Color.black700)
    }
    /// Callout 15 Regular · Black/500 (#797979).
    func calloutStyle() -> some View {
        font(.calloutText).foregroundStyle(Color.black500)
    }
    /// Subhead 14 Regular · Black/500 (#797979).
    func subheadStyle() -> some View {
        font(.subheadText).foregroundStyle(Color.black500)
    }
    /// Caption 12 Regular · Black/300 (#BCBCBC). Hints only — min 16px for Black/300.
    func captionStyle() -> some View {
        font(.captionText).foregroundStyle(Color.black300)
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
