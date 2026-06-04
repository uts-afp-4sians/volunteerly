import SwiftUI

/// Expandable "Additional filters" card shown on the Program List screen.
/// Tapping the centered title collapses the panel back to the button.
struct AdditionalFiltersPanel: View {
    @Binding var maxDistance: Double
    @Binding var memberCount: Double
    let distanceRange: ClosedRange<Double>
    let memberRange: ClosedRange<Double>
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: onToggle) {
                Text("Additional filters")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            filterRow(title: "Distance from program", value: $maxDistance, range: distanceRange)
            filterRow(title: "Number of members", value: $memberCount, range: memberRange)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func filterRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Slider(value: value, range: range)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var distance = 35.0
        @State private var members = 20.0
        var body: some View {
            AdditionalFiltersPanel(
                maxDistance: $distance,
                memberCount: $members,
                distanceRange: 0...50,
                memberRange: 0...100,
                onToggle: {}
            )
            .padding()
        }
    }
    return Demo()
}
