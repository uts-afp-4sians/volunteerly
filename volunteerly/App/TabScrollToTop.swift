import SwiftUI

/// Shared anchor id for the top of a tab's scroll content.
private enum TabScroll {
    static let topID = "tab-scroll-top"
}

extension View {
    /// Mark this view as the top anchor for `scrollsToTop(on:)`. Apply it to the
    /// top-most content view inside the scroll view, *after* its top padding, so
    /// the anchor's top equals the scroll view's natural rest position. Scrolling
    /// to it then lands exactly where iOS's own "re-tap the tab" reset lands —
    /// single-tap and double-tap agree instead of differing by the padding.
    func tabScrollTopAnchor() -> some View {
        id(TabScroll.topID)
    }
}

/// Scrolls the enclosed scroll view back to the top whenever `tab` becomes the
/// selected tab in the bottom `TabView`, so switching tabs always shows the top
/// of the page rather than a stale scroll position.
private struct ScrollsToTopOnSelect: ViewModifier {
    let tab: TabRouter.Tab
    // Optional so previews without an injected router still render (reset no-ops).
    @Environment(TabRouter.self) private var tabRouter: TabRouter?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: tabRouter?.selectedTab) { _, newTab in
                    guard newTab == tab else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(TabScroll.topID, anchor: .top)
                    }
                }
        }
    }
}

extension View {
    /// Reset this scroll view to the top when `tab` becomes selected. Requires a
    /// `TabScrollTopAnchor()` as the first child of the enclosed scroll view.
    func scrollsToTop(on tab: TabRouter.Tab) -> some View {
        modifier(ScrollsToTopOnSelect(tab: tab))
    }
}
