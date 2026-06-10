import SwiftUI

struct MainTabView: View {
    @State private var tabRouter = TabRouter()
    @State private var profileStore = UserProfileStore()
    @State private var programRefreshID = 0

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            programsTab
                .tag(TabRouter.Tab.programs)
                .tabItem { Image(systemName: "magnifyingglass") }
                .accessibilityLabel("Search")

            bookmarksTab
                .tag(TabRouter.Tab.bookmarks)
                .tabItem { Image(systemName: "bookmark") }
                .accessibilityLabel("Bookmarks")

            myPageTab
                .tag(TabRouter.Tab.myPage)
                .tabItem { Image(systemName: "person.crop.circle") }
                .accessibilityLabel("My page")
        }
        .overlay(alignment: .bottomTrailing) {
            if showsPostButton {
                Button(action: tabRouter.showPostProgram) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                        .background(Color(.systemGray6).opacity(0.9), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Post a program")
                .padding(.trailing, 20)
                .padding(.bottom, 68)
            }
        }
        .environment(tabRouter)
        .environment(profileStore)
    }

    private var programsTab: some View {
        NavigationStack(path: $tabRouter.programsPath) {
            ProgramListView(refreshID: programRefreshID)
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
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
    }

    private var bookmarksTab: some View {
        NavigationStack {
            BookmarksView()
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
                }
        }
    }

    private var myPageTab: some View {
        NavigationStack {
            MyPageView()
                .navigationDestination(for: Int.self) { programId in
                    ProgramDetailView(programId: programId)
                }
        }
    }

    private var showsPostButton: Bool {
        tabRouter.selectedTab == .programs && tabRouter.programsPath.isEmpty
    }
}

#Preview { MainTabView() }
