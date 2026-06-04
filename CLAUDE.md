# CLAUDE.md

Guidance for working in this repo. Keep it short — document conventions that
aren't obvious from the code, not things the code already shows.

## Layout
- `volunteerly/` + `volunteerly.xcodeproj` — SwiftUI iOS app (the mobile client).
- `api/` — FastAPI backend (Python, uv + Turso/SQLite), `mise` tasks.
- `api/openapi.json` — the API contract, the single source of truth for codegen.

## iOS build / run
- The machine's `xcode-select` points at CommandLineTools, so prefix Xcode tools
  with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Build: `xcodebuild -project volunteerly.xcodeproj -scheme volunteerly -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- The target uses **file-system-synchronized groups** — new files under
  `volunteerly/` are auto-included; no `.pbxproj` edits needed to add sources.
- The app starts at a splash that only routes to the main UI when a session
  exists. To reach it in the simulator, inject one at launch:
  `xcrun simctl launch booted com.4sians.volunteerly -auth_token mock`.

## Design system
**Always use the design tokens — never hardcode hex or `.system(size:)`.**
- Colours live in `Assets.xcassets` and are exposed as auto-generated symbols:
  `Color.brand/.brandLight/.brandDark`, `.secondaryBlue/.secondaryBlueLight/.secondaryBlueDark`,
  `.accentYellow/.accentYellowLight/.accentYellowDark`, `.pageBackground`, `.textPrimary`,
  `.fieldError`. `AccentColor` (`Color.accent`) is the brand green global tint.
- Typography + text-style helpers are in `volunteerly/Shared/DesignSystem/Typography.swift`:
  `Font.pageTitle/.subheading/.sectionHeader/.bodyStrong/.bodyText/.buttonLabel/.labelItalic`,
  plus `Text.requiredFieldStyle()` and `.linkStyle()`.
- **Naming gotcha (don't "fix"):** the blue and yellow families are named
  `SecondaryBlue*` / `AccentYellow*`, not `Secondary*` / `Accent*`, on purpose —
  the short names collide with the built-in `Color.secondary` and the `AccentColor`
  symbol and reintroduce build warnings.

## API client codegen
- `mise gen:api` regenerates everything: `api gen:openapi` (FastAPI → `api/openapi.json`)
  then `gen:api:mobile` (swift-openapi-generator → `volunteerly/Core/Networking/Generated/`).
- Generated `Client.swift`/`Types.swift` are committed — **regenerate, don't hand-edit.**
  `openapi-generator-config.yaml` filters by tag to keep output small; widen it as new
  screens consume new resources.
- **The spec is OpenAPI 3.0, not 3.1 — do not revert.** `api/scripts/gen_openapi.py`
  down-converts FastAPI's 3.1 output to 3.0.3 because swift-openapi-generator drops
  3.1's `anyOf:[X,{type:null}]` nullable fields; 3.0's `nullable:true` round-trips correctly.
- `API.makeClient()` (`APIClient.swift`) builds the generated client over URLSession; it
  coexists with the existing `HTTPClient`/`MockHTTPClient` mock layer (no full migration yet).

## Naming
- The forum feature is `Forum*` in iOS code (`ForumPost`, `ForumComment`) even though the
  ERD calls it `BOARD_*`. Keep "Forum" in iOS and API code/UI; the JSON keys already match.
