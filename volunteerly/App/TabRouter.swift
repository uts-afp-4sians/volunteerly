import SwiftUI

/// Drives the root tab selection and the Programs tab's navigation stack so any
/// menu can route back to the app home (the Programs tab at its root).
@MainActor
@Observable
final class TabRouter {
    enum Tab: Hashable {
        case programs
        case bookmarks
        case settings
    }

    enum ProgramsDestination: Hashable {
        case post
    }

    var selectedTab: Tab = .programs
    var programsPath = NavigationPath()

    /// Return to the home page: select the Programs tab and pop it to its root.
    func goHome() {
        selectedTab = .programs
        programsPath = NavigationPath()
    }

    func showPostProgram() {
        selectedTab = .programs
        programsPath.append(ProgramsDestination.post)
    }
}

/// Route value pushed by the top-right avatar to open the signed-in user's
/// profile (`MyPageView`). Each tab's `NavigationStack` registers a
/// `navigationDestination(for: ProfileRoute.self)` mapping to `MyPageView`.
struct ProfileRoute: Hashable {}
