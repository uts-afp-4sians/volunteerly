import SwiftUI

/// A square interest/category chip with an icon tile and a label underneath,
/// matching the horizontal "Interest" row in the Find New Opportunities design.
struct CategoryChip: View {
    let category: ProgramCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.brandLight : Color(.systemGray6))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(UserProfileStore.emoji(for: category.name))
                            .font(.system(size: 24))
                    )

                // Figma 190:639: every category label stays #1f1f1f regular —
                // selection is signalled by the green tile, not the label.
                Text(category.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}

/// Loading placeholder that mirrors `CategoryChip`'s layout (50×50 tile + label
/// bar) so the category row keeps its size while categories are fetched. Pulses
/// gently, and stays static when Reduce Motion is on (HIG).
struct CategoryChipSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 11)
        }
        .frame(width: 56)
        .opacity(pulsing ? 0.45 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear { pulsing = true }
    }
}

#Preview {
    HStack {
        CategoryChip(category: MockData.categories[0], isSelected: false, action: {})
        CategoryChip(category: MockData.categories[1], isSelected: true, action: {})
        CategoryChipSkeleton()
        CategoryChipSkeleton()
    }
    .padding()
}
