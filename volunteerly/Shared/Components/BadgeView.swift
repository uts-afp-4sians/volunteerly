import SwiftUI

struct BadgeView: View {
    let status: ProgramStatus

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .open:      .green
        case .full:      .orange
        case .closed, .cancelled: .red
        case .draft:     .gray
        }
    }
}

#Preview {
    HStack {
        BadgeView(status: .open)
        BadgeView(status: .full)
        BadgeView(status: .closed)
    }
    .padding()
}
