import SwiftUI

/// A custom progress bar component conforming to the design system.
///
/// - Height: 11
/// - Corner Radius: 8
/// - Background: `#E9E9EB`
/// - Progress Fill: `Color.secondaryBlue` (#5F799D)
struct ProgressBar: View {
    let progress: Double  // 0...1

    private let height: CGFloat = 11
    private let cornerRadius: CGFloat = 8
    private let trackColor = Color(red: 0.914, green: 0.914, blue: 0.918) // #E9E9EB

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(trackColor)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.secondaryBlue)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
    }
}

#Preview("ProgressBar states") {
    struct Demo: View {
        @State private var progress: Double = 0.5
        var body: some View {
            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("0% Progress").font(.labelItalic)
                    ProgressBar(progress: 0.0)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("50% Progress").font(.labelItalic)
                    ProgressBar(progress: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("100% Progress").font(.labelItalic)
                    ProgressBar(progress: 1.0)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interactive").font(.labelItalic)
                    ProgressBar(progress: progress)
                    Slider(value: $progress, in: 0...1)
                }
            }
            .padding(40)
            .background(Color.pageBackground)
        }
    }
    return Demo()
}
