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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: Self.symbolName(for: category.name))
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                    )

                Text(category.name)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }

    static func symbolName(for category: String) -> String {
        switch category.lowercased() {
        case "environment": "leaf.fill"
        case "community":   "person.3.fill"
        case "education":   "book.fill"
        case "health":      "heart.fill"
        case "animals":     "pawprint.fill"
        case "seniors":     "figure.roll"
        case "food":        "fork.knife"
        case "arts":        "paintpalette.fill"
        default:            "square.grid.2x2.fill"
        }
    }
}

#Preview {
    HStack {
        CategoryChip(category: MockData.categories[0], isSelected: false, action: {})
        CategoryChip(category: MockData.categories[1], isSelected: true, action: {})
    }
    .padding()
}
