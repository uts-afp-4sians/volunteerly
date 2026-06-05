import SwiftUI

/// A compact, icon-only button rendered on a light-gray (`IconButtonFill`) shape.
///
/// Per the buttons spec the look is composed from two orthogonal props — `shape`
/// (`.circle` / `.square`) and `size` (`.small` / `.large`). The glyph (e.g.
/// `+`, `>`) is an SF Symbol at SF Pro 36 (`Font.iconButtonGlyph`) in
/// `Color.textPrimary`.
///
/// | shape + size       | Footprint | Padding | Corner             |
/// |--------------------|-----------|---------|--------------------|
/// | `.circle` `.small` | 58×58     | 8       | circle             |
/// | `.circle` `.large` | 87×87     | 16      | circle             |
/// | `.square` `.small` | 58×58     | 8       | corner radius 8    |
/// | `.square` `.large` | 87×87     | 16      | corner radius 12   |
struct IconButton: View {
    enum Shape {
        case circle
        case square
    }

    enum Size {
        case small
        case large

        /// Outer width/height of the button, in points.
        var dimension: CGFloat {
            switch self {
            case .small: return 58
            case .large: return 87
            }
        }

        /// Inset between the shape edge and the glyph.
        var padding: CGFloat {
            switch self {
            case .small: return 8
            case .large: return 16
            }
        }

        /// Corner radius used when `shape` is `.square`.
        var squareCornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .large: return 12
            }
        }
    }

    let systemName: String
    let shape: Shape
    let size: Size
    let action: () -> Void

    init(systemName: String, shape: Shape, size: Size, action: @escaping () -> Void) {
        self.systemName = systemName
        self.shape = shape
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.iconButtonGlyph)
                .foregroundStyle(Color.textPrimary)
                .padding(size.padding)
                .frame(width: size.dimension, height: size.dimension)
                .background(backgroundShape.fill(Color.iconButtonFill))
                .contentShape(backgroundShape)
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: AnyShape {
        switch shape {
        case .circle:
            return AnyShape(Circle())
        case .square:
            return AnyShape(
                RoundedRectangle(cornerRadius: size.squareCornerRadius, style: .continuous)
            )
        }
    }
}

#Preview("IconButton variants") {
    Grid(horizontalSpacing: 24, verticalSpacing: 24) {
        GridRow {
            Text("Small Circle").font(.bodyStrong).gridColumnAlignment(.leading)
            IconButton(systemName: "plus", shape: .circle, size: .small) {}
            IconButton(systemName: "chevron.right", shape: .circle, size: .small) {}
        }
        GridRow {
            Text("Large Circle").font(.bodyStrong)
            IconButton(systemName: "plus", shape: .circle, size: .large) {}
            IconButton(systemName: "chevron.right", shape: .circle, size: .large) {}
        }
        GridRow {
            Text("Small Square").font(.bodyStrong)
            IconButton(systemName: "plus", shape: .square, size: .small) {}
            IconButton(systemName: "chevron.right", shape: .square, size: .small) {}
        }
        GridRow {
            Text("Large Square").font(.bodyStrong)
            IconButton(systemName: "plus", shape: .square, size: .large) {}
            IconButton(systemName: "chevron.right", shape: .square, size: .large) {}
        }
    }
    .padding(40)
    .background(Color.pageBackground)
}
