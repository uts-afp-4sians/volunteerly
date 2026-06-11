import SwiftUI
import UIKit

/// A full-screen, dark-backdrop image viewer. Shows the original (uncropped)
/// image with `contentMode: .fit`, supports pinch / double-tap zoom, and pages
/// between multiple images seeded to the index the caller was viewing.
struct FullScreenImageViewer: View {
    let urls: [String]
    @State private var selection: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [String], initialIndex: Int = 0) {
        self.urls = urls
        let clamped = min(max(initialIndex, 0), max(urls.count - 1, 0))
        _selection = State(initialValue: clamped)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    ZoomableImage(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
    }
}

/// One image with independent pinch-to-zoom, double-tap-to-zoom, and pan when
/// zoomed in. Pan is only enabled while zoomed so it doesn't fight the pager's
/// horizontal swipe at 1×.
private struct ZoomableImage: View {
    let url: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var loaded: UIImage?
    @State private var failed = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        Group {
            if let image = loaded ?? URL(string: url).flatMap(ImageCache.shared.cached) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification)
                    .simultaneousGesture(scale > 1 ? pan : nil)
                    .onTapGesture(count: 2) { toggleZoom() }
            } else if failed {
                Image(systemName: "photo")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) { await load() }
    }

    private func load() async {
        guard loaded == nil, let target = URL(string: url) else { return }
        if let image = await ImageCache.shared.image(for: target) {
            loaded = image
        } else {
            failed = true
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale { resetZoom() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if scale > minScale {
                resetZoom()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    FullScreenImageViewer(
        urls: ["https://picsum.photos/800/1200", "https://picsum.photos/1200/800"],
        initialIndex: 0
    )
}
