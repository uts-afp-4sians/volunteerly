import SwiftUI

/// Circular profile avatar with three states from Figma `group-4-prototype`:
/// - **default** — light-gray circle with a person silhouette (node 226:263)
/// - **uploaded** — the supplied image fills the whole circle (node 226:264)
/// - **upload prompt** — light-gray circle with a centred camera icon that
///   invites the user to add a photo (node 226:786)
struct Avatar: View {
    /// What to render inside the circle.
    enum Source: Equatable {
        case placeholder
        case uploadPrompt
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
        case .uploadPrompt:
            uploadPrompt
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

    /// Light-gray fill with a centred camera icon prompting the user to upload
    /// a photo. Per Figma: circle `#F5F5F5`, camera `#DDDDDD`, SF Pro Bold 30px
    /// on the 136pt reference circle (≈ 22% of the diameter), so it scales with
    /// `size`.
    private var uploadPrompt: some View {
        Circle()
            .fill(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
            .overlay {
                Image(systemName: "camera.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(Color(red: 221 / 255, green: 221 / 255, blue: 221 / 255))
                    .frame(width: size * 0.26)
            }
    }
}

#Preview {
    HStack(spacing: 24) {
        VStack {
            Avatar(source: .placeholder, size: 100)
            Text("default")
        }
        VStack {
            Avatar(source: .image(Image(systemName: "photo.fill")), size: 100)
            Text("uploaded")
        }
        VStack {
            Avatar(source: .uploadPrompt, size: 100)
            Text("upload prompt")
        }
    }
    .padding()
}
