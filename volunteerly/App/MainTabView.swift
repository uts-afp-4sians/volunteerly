import SwiftUI

struct MainTabView: View {
    @State private var tabRouter = TabRouter()
    // App-wide profile store, hydrated by the profile screen on appearance.
    @State private var profileStore = UserProfileStore()

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            NavigationStack(path: $tabRouter.programsPath) {
                ProgramListView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
            }
            .tag(TabRouter.Tab.programs)
            .tabItem { SwiftUI.Label("Programs", systemImage: "list.bullet") }

            NavigationStack {
                MyPageView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
            }
            .tag(TabRouter.Tab.myPage)
            .tabItem { SwiftUI.Label("My page", systemImage: "person.crop.circle") }
        }
        .environment(tabRouter)
        .environment(profileStore)
    }
}

#Preview { MainTabView() }
