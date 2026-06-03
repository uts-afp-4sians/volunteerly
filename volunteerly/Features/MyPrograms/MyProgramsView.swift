import SwiftUI

struct MyProgramsView: View {
    var body: some View {
        NavigationStack {
            Text("Coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("My Programs")
        }
    }
}

#Preview { MyProgramsView() }
