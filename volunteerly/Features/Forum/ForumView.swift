import SwiftUI

struct ForumView: View {
    let programId: Int

    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("Forum")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { ForumView(programId: 1) }
