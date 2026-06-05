import SwiftUI

struct MainTabView: View {
    @State private var tabRouter = TabRouter()

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
                MyProgramsView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
            }
            .tag(TabRouter.Tab.myPrograms)
            .tabItem { SwiftUI.Label("My Programs", systemImage: "person.crop.circle") }
        }
        .environment(tabRouter)
    }
}

#Preview { MainTabView() }
