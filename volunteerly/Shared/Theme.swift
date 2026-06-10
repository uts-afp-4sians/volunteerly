import SwiftUI

enum Theme {
    static let background    = Color.pageBackground
    static let card          = Color.white
    static let gold          = Color.accentYellow
    static let forest        = Color.brand
    static let forestLight    = Color.brandLight
    static let onBrand        = Color.onBrand
    static let textPrimary   = Color.textPrimary
    static let textSecondary = Color(red: 0.53, green: 0.53, blue: 0.50)  // #888880
    static let border        = Color(red: 0.90, green: 0.90, blue: 0.88)
    static let success       = Color(red: 0.11, green: 0.62, blue: 0.46)  // #1D9E75

    // MARK: - Figma design tokens (nodes 450:751 colours, 468:751 type)
    //
    // The numeric scale below mirrors the Figma "🎨 Color Tokens" sheet 1:1 via
    // auto-generated asset symbols (e.g. `Color.brand400`). The semantic aliases
    // beneath map a token to its design-system role so screens reference intent,
    // not a raw shade. Prefer the semantic name; reach for the raw scale only
    // when a one-off shade is genuinely needed.

    // Brand
    static let brand1000 = Color.brand1000   // #373A1F
    static let brand700  = Color.brand700    // #586637
    static let brand500  = Color.brand500    // #65753E
    static let brand400  = Color.brand400    // #8B9D60
    static let brand300  = Color.brand300    // #A5B383
    static let brand100  = Color.brand100    // #DDDECA

    // Secondary (blue)
    static let secondary500 = Color.secondaryBlue500  // #395275
    static let secondary300 = Color.secondaryBlue300  // #74869E
    static let secondary100 = Color.secondaryBlue100  // #C4CBD6

    // Black scale
    static let black900 = Color.black900  // #1C1C1C
    static let black700 = Color.black700  // #4C4C4C
    static let black500 = Color.black500  // #797979
    static let black300 = Color.black300  // #BCBCBC
    static let black100 = Color.black100  // #E9E9E9
    static let black50  = Color.black50   // #F5F5F5

    static let iconPrimary = Color.iconPrimary  // #1F1F1F

    // MARK: Semantic roles (Figma usage)

    /// Primary action / filled button background. (Figma: Brand/400)
    static let brandPrimary   = Color.brand400
    /// Selected chip / active accent fill. (Figma: Brand/300)
    static let brandSelected  = Color.brand300
    /// Input field & search-bar fill, neutral surface. (Figma: Black/50)
    static let surface        = Color.black50
    /// Hairline divider & subtle field border. (Figma: Black/100)
    static let divider        = Color.black100
    /// Placeholder / disabled hint text. (Figma: Black/300)
    static let placeholder    = Color.black300
    /// Primary body & headline text on white. (Figma: Black/700)
    static let textBody       = Color.black700
    /// Meta text — callouts, dates, locations. (Figma: Black/500)
    static let textMeta       = Color.black500
}
