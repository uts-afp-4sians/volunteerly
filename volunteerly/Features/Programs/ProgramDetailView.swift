import SwiftUI

struct ProgramDetailView: View {
    let programId: Int

    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("Program Detail")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { ProgramDetailView(programId: 1) }
