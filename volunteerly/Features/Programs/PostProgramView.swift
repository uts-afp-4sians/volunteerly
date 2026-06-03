import SwiftUI

struct PostProgramView: View {
    var body: some View {
        NavigationStack {
            Text("Coming soon")
                .foregroundStyle(.secondary)
                .navigationTitle("Post a Program")
        }
    }
}

#Preview { PostProgramView() }
