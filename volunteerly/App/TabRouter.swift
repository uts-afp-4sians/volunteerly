import SwiftUI

/// Drives the root tab selection and the Programs tab's navigation stack so any
/// menu can route back to the app home (the Programs tab at its root).
@MainActor
@Observable
final class TabRouter {
    enum Tab: Hashable {
        case programs
        case myPage
    }

    var selectedTab: Tab = .programs
    var programsPath = NavigationPath()

    /// Return to the home page: select the Programs tab and pop it to its root.
    func goHome() {
        selectedTab = .programs
        programsPath = NavigationPath()
    }
}
