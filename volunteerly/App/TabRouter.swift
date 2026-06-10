import SwiftUI

/// Drives the root tab selection and each tab's navigation stack so any menu
/// can route back to the app home (the Programs tab at its root) and the
/// header's gear can push Settings onto whichever tab is currently visible.
@MainActor
@Observable
final class TabRouter {
    enum Tab: Hashable {
        case programs
        case bookmarks
        case myPage
    }

    enum ProgramsDestination: Hashable {
        case post
    }

    var selectedTab: Tab = .programs
    var programsPath = NavigationPath()
    var bookmarksPath = NavigationPath()
    var myPagePath = NavigationPath()

    /// Return to the home page: select the Programs tab and pop it to its root.
    func goHome() {
        selectedTab = .programs
        programsPath = NavigationPath()
    }

    func showPostProgram() {
        selectedTab = .programs
        programsPath.append(ProgramsDestination.post)
    }

    /// Push the Settings screen onto the currently visible tab's stack. Done
    /// here (router-owned paths) rather than via `NavigationLink` so the push
    /// can never land on a neighbouring page-style tab's stack.
    func showSettings() {
        switch selectedTab {
        case .programs: programsPath.append(SettingsRoute())
        case .bookmarks: bookmarksPath.append(SettingsRoute())
        case .myPage: myPagePath.append(SettingsRoute())
        }
    }
}

/// Route value pushed by the header's gear button to open `SettingsView`.
/// Each tab's `NavigationStack` registers a
/// `navigationDestination(for: SettingsRoute.self)` mapping to it.
struct SettingsRoute: Hashable {}
