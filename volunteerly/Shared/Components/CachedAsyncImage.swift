import SwiftUI
import UIKit

/// Drop-in replacement for `AsyncImage` that adds caching so list images don't
/// re-download every time a cell is recycled while scrolling.
///
/// Two layers back it:
/// - an in-memory `NSCache` of decoded `UIImage`s, keyed by URL, so a card that
///   scrolls back into view paints instantly with no network or decode work;
/// - a disk-backed `URLCache` on a shared `URLSession`, so images survive across
///   app launches and only hit the network once.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var loaded: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loaded ?? url.flatMap(ImageCache.shared.cached) {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let url, loaded == nil else { return }
        if let image = await ImageCache.shared.image(for: url) {
            loaded = image
        }
    }
}

/// Shared image cache + loader. The memory cache is checked synchronously so the
/// view can paint without a flash; misses go through the disk-cached session.
final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        let cache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,   // 16 MB
            diskCapacity: 128 * 1024 * 1024,    // 128 MB
            diskPath: "volunteerly-images"
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        memory.countLimit = 200
    }

    /// Synchronous memory-cache lookup — nil on miss, no I/O.
    func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    /// Returns the image for `url`, fetching (and caching) it on a memory miss.
    func image(for url: URL) async -> UIImage? {
        if let hit = memory.object(forKey: url as NSURL) { return hit }
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}
