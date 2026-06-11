import SwiftUI

/// Route value for the "Add post" link — pushes the New post page.
struct NewPostRoute: Hashable {
    let programId: Int
}

/// The Community Board block shown at the bottom of a joined program's detail:
/// a "Community Board" header with an "Add post" link, a single sort chip, and
/// a two-column grid of question cards. Matches Figma `group-4-prototype`
/// Community Board (node 398:989).
struct MemberBoardSection: View {
    @State private var viewModel: MemberBoardViewModel
    private let httpClient: HTTPClient

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
        _viewModel = State(initialValue: MemberBoardViewModel(programId: programId, httpClient: httpClient))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            BoardSortChip(selection: $viewModel.sort)
            content
        }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.load()
            }
        }
        .navigationDestination(for: ForumPost.self) { post in
            ForumThreadView(post: post, currentUserId: 1, httpClient: httpClient)
        }
        .navigationDestination(for: NewPostRoute.self) { _ in
            NewPostView(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Community Board")
                .font(.pageTitle)
                .tracking(-0.3)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            NavigationLink(value: NewPostRoute(programId: viewModel.programId)) {
                Text("Add post")
                    .font(.bodyText)
                    .italic()
                    .foregroundStyle(Theme.placeholder)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add post")
            .accessibilityHint("Opens a page to write a new post")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
            Text(error)
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.posts.isEmpty {
            Text("No questions yet. Be the first to start a conversation.")
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            QuestionGrid(posts: viewModel.sortedPosts)
        }
    }
}

/// A single chip that cycles the board order on each tap
/// (Newest → Top → Oldest). Styled as a soft grey capsule with a chevron,
/// matching the Figma `group-4-prototype` board.
struct BoardSortChip: View {
    @Binding var selection: BoardSort

    var body: some View {
        Button {
            withAnimation(.snappy) { selection = selection.next }
        } label: {
            HStack(spacing: 6) {
                Text(selection.label)
                    .font(.bodyText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort order")
        .accessibilityValue(selection.label)
        .accessibilityHint("Double tap to change the order")
    }
}

/// Two-column grid of question cards. Each card pushes the forum thread for
/// its post.
struct QuestionGrid: View {
    let posts: [ForumPost]

    private let columns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 11) {
            ForEach(posts) { post in
                NavigationLink(value: post) {
                    QuestionCard(post: post)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A single board card: the question title over its description, on a soft
/// grey tile.
struct QuestionCard: View {
    let post: ForumPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(post.body)
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 165, alignment: .topLeading)
        .padding(16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ScrollView {
            MemberBoardSection(programId: 1, httpClient: MockHTTPClient.shared)
                .padding(20)
        }
    }
}
