# Volunteerly Design System

## 1. Visual Theme & Atmosphere

Clean, approachable native iOS UI with consistent alignment across root tabs.

## 2. Color Palette & Roles

- Existing `Theme.background`: root screen background
- Existing `Color.textPrimary`: primary content
- Existing `Theme.textSecondary`: supporting content
- Existing `Color.brand`: actions and selected states

## 3. Typography Rules

Use the existing SwiftUI typography tokens and system Dynamic Type behavior.

| Role | Token | Usage |
|---|---|---|
| Page title | `.pageTitle` | Root screen title |
| Body | `.bodyText` | Standard content |
| Strong body | `.bodyStrong` | Emphasized content |

## 4. Component Stylings

Every root tab begins with `VolunteerlyHeader`. My Page must not use a separate
wordmark implementation. Existing profile controls remain unchanged.

## 5. Layout Principles

- Root `VStack` spacing: 20pt
- Horizontal padding: 20pt
- Top padding: 16pt
- Bottom padding: 24pt
- Background: `Theme.background.ignoresSafeArea()`
- Navigation bar: hidden

## 6. Depth & Elevation

Use existing native materials and component elevation. Do not add new shadows or
containers solely for My Page.

## 7. Do's and Don'ts

- Do align My Page with Search and Bookmarks.
- Do retain My Page profile-specific sections.
- Don't use 24pt horizontal padding, 8pt top padding, or 28pt root spacing.
- Don't duplicate the Volunteerly wordmark.

## 8. Responsive Behavior

The shared shell applies at all iPhone widths. Content remains scrollable,
supports Dynamic Type, and respects the native tab-bar safe area.

## 9. Agent Prompt Guide

Update `MyPageView` to use the same root shell as Search and Bookmarks:
`VolunteerlyHeader`, 20pt horizontal padding, 16pt top padding, 20pt root
spacing, 24pt bottom padding, and `Theme.background`. Remove the local wordmark
property. Preserve all profile forms, loading behavior, sheets, account actions,
and native tab behavior. Build, test, and verify on the connected iPhone.
