import SwiftUI

struct ProgressBar: View {
    let progress: Double  // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.border)
                Capsule()
                    .fill(Theme.forest)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}
