import SwiftUI

/// "Dot swipe" page indicator for an image carousel, from Figma
/// `group-4-prototype` (node 226:295).
///
/// Per spec: dots are **12×12**, **17pt** apart, and the row sits **21pt** from
/// the bottom edge of the image (apply that inset at the call site — the outer
/// container is "dependent on use case"). Inactive dots are `#DDDDDD`; the
/// selected dot is filled with a darker neutral so the current page reads.
struct PageDots: View {
    let count: Int
    let selection: Int
    var size: CGFloat = 12
    var spacing: CGFloat = 17
    var activeColor: Color = Color(red: 148 / 255, green: 148 / 255, blue: 148 / 255)   // #949494
    var inactiveColor: Color = Color(red: 221 / 255, green: 221 / 255, blue: 221 / 255) // #DDDDDD

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == selection ? activeColor : inactiveColor)
                    .frame(width: size, height: size)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selection)
        .accessibilityElement()
        .accessibilityLabel("Page \(selection + 1) of \(count)")
    }
}

#Preview {
    VStack(spacing: 24) {
        // The carousel container is "dependent on use case"; this mirrors the
        // 394×253 #F4F4F4 placeholder shown in the design board.
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 244 / 255, green: 244 / 255, blue: 244 / 255))
            .frame(width: 394, height: 253)
            .overlay(alignment: .bottom) {
                PageDots(count: 3, selection: 0)
                    .padding(.bottom, 21)
            }
    }
    .padding()
}
