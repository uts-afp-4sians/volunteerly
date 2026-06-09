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
                    .navigationDestination(for: ProfileRoute.self) { _ in
                        ProfileSettingsView()
                    }
            }
            .tag(TabRouter.Tab.programs)
            .tabItem { SwiftUI.Label("Programs", systemImage: "list.bullet") }

            NavigationStack {
                MyProgramsView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
                    .navigationDestination(for: ProfileRoute.self) { _ in
                        ProfileSettingsView()
                    }
            }
            .tag(TabRouter.Tab.myPrograms)
            .tabItem { SwiftUI.Label("My Programs", systemImage: "person.crop.circle") }
        }
        .environment(tabRouter)
        .environment(profileStore)
    }
}

#Preview { MainTabView() }
