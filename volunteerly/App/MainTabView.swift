import SwiftUI

struct MainTabView: View {
    @State private var tabRouter = TabRouter()
    @State private var profileStore = UserProfileStore()
    @State private var programRefreshID = 0

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            programsTab.tag(TabRouter.Tab.programs)
            bookmarksTab.tag(TabRouter.Tab.bookmarks)
            settingsTab.tag(TabRouter.Tab.settings)
        }
        .environment(tabRouter)
        .environment(profileStore)
    }

    private var programsTab: some View {
        NavigationStack(path: $tabRouter.programsPath) {
            ProgramListView(refreshID: programRefreshID)
                .safeAreaInset(edge: .bottom) {
                    floatingBar(showsPostButton: true)
                }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
                }
                .navigationDestination(for: ProfileRoute.self) { _ in
                    MyPageView()
                }
                .navigationDestination(for: TabRouter.ProgramsDestination.self) { destination in
                    switch destination {
                    case .post:
                        PostProgramView {
                            programRefreshID += 1
                        }
                    }
                }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var bookmarksTab: some View {
        NavigationStack {
            BookmarksView()
                .safeAreaInset(edge: .bottom) { floatingBar() }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
                }
                .navigationDestination(for: ProfileRoute.self) { _ in
                    MyPageView()
                }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var settingsTab: some View {
        NavigationStack {
            SettingsView()
                .safeAreaInset(edge: .bottom) { floatingBar() }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
                }
                .navigationDestination(for: ProfileRoute.self) { _ in
                    MyPageView()
                }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    /// The custom floating tab bar. Mounted on each tab's root via
    /// `safeAreaInset` so it floats above the content and is covered (hidden)
    /// when a detail is pushed onto the stack.
    private func floatingBar(showsPostButton: Bool = false) -> some View {
        FloatingTabBar(
            selection: $tabRouter.selectedTab,
            showsPostButton: showsPostButton,
            onPostProgram: tabRouter.showPostProgram
        )
    }
}

#Preview { MainTabView() }
