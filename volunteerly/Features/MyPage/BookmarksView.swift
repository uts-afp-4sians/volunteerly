import SwiftUI

struct BookmarksView: View {
    @State private var viewModel: MyPageViewModel
    @Environment(BookmarkStore.self) private var bookmarkStore: BookmarkStore?

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyPageViewModel(httpClient: httpClient))
    }

    /// The cached program pool filtered by the shared bookmark set. Re-derives
    /// instantly when a toggle (here or in a program's detail) mutates the store.
    private var bookmarks: [Program] {
        viewModel.bookmarkPrograms(bookmarkedIds: bookmarkStore?.ids ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bookmarks")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .tabScrollTopAnchor()
        }
        .scrollsToTop(on: .bookmarks)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.programs.isEmpty {
                await viewModel.load(includeMyPrograms: false)
            }
        }
        .refreshable {
            await viewModel.load(includeMyPrograms: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            LazyVStack(spacing: 23) {
                ForEach(0..<3, id: \.self) { _ in
                    BookmarkRowSkeleton()
                }
            }
            .shimmering()
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Something went wrong",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding(.top, 40)
        } else if bookmarks.isEmpty {
            ContentUnavailableView("No bookmarks yet", systemImage: "bookmark")
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 23) {
                ForEach(bookmarks) { program in
                    NavigationLink(value: program.id) {
                        BookmarkRow(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Compact bookmark list row — a 69×69 rounded thumbnail beside the program
/// name, vertically centred. Matches the Bookmarks design (Figma `390:1030`).
private struct BookmarkRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 17) {
            CachedAsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(.systemGray6))
            }
            .frame(width: 69, height: 69)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(program.name)
                .font(.bodyStrong)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// Placeholder row shown while bookmarks load — mirrors `BookmarkRow`'s
/// geometry (69×69 thumbnail + two text lines) so the list doesn't reflow when
/// real content arrives. Animated by the parent's `.shimmering()`.
private struct BookmarkRowSkeleton: View {
    private var fill: Color { Color(.systemGray5) }

    var body: some View {
        HStack(spacing: 17) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fill)
                .frame(width: 69, height: 69)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill)
                    .frame(width: 140, height: 14)
            }

            Spacer(minLength: 0)
        }
    }
}

/// Sweeps a soft highlight across the view to signal loading. Honours Reduce
/// Motion by falling back to a static, slightly-dimmed state.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(0.6)
        } else {
            content
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                }
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

private extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        BookmarksView(httpClient: MockHTTPClient.shared)
    }
    .environment(TabRouter())
    .environment(BookmarkStore())
}
