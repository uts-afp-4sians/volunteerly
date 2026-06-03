import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ProgramListView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
            }
            .tabItem { Label("Programs", systemImage: "list.bullet") }

            NavigationStack {
                MyProgramsView()
                    .navigationDestination(for: Int.self) { programId in
                        ProgramDetailView(programId: programId)
                    }
            }
            .tabItem { Label("My Programs", systemImage: "person.crop.circle") }
        }
    }
}

#Preview { MainTabView() }
