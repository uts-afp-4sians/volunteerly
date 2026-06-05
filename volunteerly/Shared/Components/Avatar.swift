import SwiftUI

/// Circular profile avatar with two states from Figma `group-4-prototype`:
/// - **default** — light-gray circle with a person silhouette (node 226:264)
/// - **uploaded** — the supplied image fills the whole circle (node 226:263)
struct Avatar: View {
    /// What to render inside the circle.
    enum Source: Equatable {
        case placeholder
        case remote(URL?)
        case image(Image)
    }

    let source: Source
    var size: CGFloat = 136

    init(source: Source, size: CGFloat = 136) {
        self.source = source
        self.size = size
    }

    /// Convenience: render a remote image, falling back to the placeholder
    /// silhouette when the URL is `nil` or fails to load.
    init(url: URL?, size: CGFloat = 136) {
        self.source = .remote(url)
        self.size = size
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var content: some View {
        switch source {
        case .placeholder:
            placeholder
        case .image(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .remote(let url):
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholder
            }
        }
    }

    /// Light-gray fill with a centred person silhouette. The silhouette is
    /// sized so its shoulders are clipped by the surrounding circle.
    private var placeholder: some View {
        Circle()
            .fill(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
            .overlay {
                Image(systemName: "person.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color(uiColor: .systemGray3))
                    .frame(width: size * 0.55)
                    .offset(y: size * 0.13)
            }
    }
}

#Preview {
    HStack(spacing: 40) {
        VStack {
            Avatar(source: .placeholder)
            Text("default")
        }
        VStack {
            Avatar(source: .image(Image(systemName: "photo.fill")))
            Text("uploaded")
        }
    }
    .padding()
}
