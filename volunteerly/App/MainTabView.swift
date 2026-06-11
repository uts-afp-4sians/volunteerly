import SwiftUI

struct MainTabView: View {
    @State private var tabRouter = TabRouter()
    @State private var profileStore = UserProfileStore()
    @State private var programRefreshID = 0

    var body: some View {
        // Default tab style (not .page): tabs switch only via the floating
        // bar — no horizontal swipe between menus — and each page keeps its
        // own state. The native tab bar stays hidden per-tab via
        // `.toolbar(.hidden, for: .tabBar)`.
        TabView(selection: $tabRouter.selectedTab) {
            programsTab.tag(TabRouter.Tab.programs)
            bookmarksTab.tag(TabRouter.Tab.bookmarks)
            myPageTab.tag(TabRouter.Tab.myPage)
        }
        .environment(tabRouter)
        .environment(profileStore)
        // Hydrate the signed-in profile once at the app root so `currentUserId`
        // is available on every tab — not just after My Page is visited. Without
        // this, opening your own program from the Programs tab first leaves
        // `currentUserId` nil, so `ProgramDetailView.isHost` reads false and the
        // owner sees the "Joined" join bar instead of the host "…" menu.
        // Cache-first and idempotent; safe to call alongside My Page's own load.
        .task { await profileStore.load() }
    }

    private var programsTab: some View {
        NavigationStack(path: $tabRouter.programsPath) {
            ProgramListView(refreshID: programRefreshID)
                .safeAreaInset(edge: .bottom) {
                    floatingBar(showsPostButton: true)
                }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId) {
                        programRefreshID += 1
                    }
                }
                .navigationDestination(for: SettingsRoute.self) { _ in
                    SettingsView()
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
        NavigationStack(path: $tabRouter.bookmarksPath) {
            BookmarksView()
                .safeAreaInset(edge: .bottom) { floatingBar() }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId) {
                        programRefreshID += 1
                    }
                }
                .navigationDestination(for: SettingsRoute.self) { _ in
                    SettingsView()
                }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var myPageTab: some View {
        NavigationStack(path: $tabRouter.myPagePath) {
            MyPageView()
                .safeAreaInset(edge: .bottom) { floatingBar() }
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId) {
                        programRefreshID += 1
                    }
                }
                .navigationDestination(for: SettingsRoute.self) { _ in
                    SettingsView()
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
