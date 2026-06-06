import SwiftUI

/// Route value for the "more+" link — pushes the full Member board.
private struct MemberBoardLink: Hashable {
    let programId: Int
}

/// The Member board block shown at the bottom of a joined program's detail:
/// a "Member board" header with a "more+" link, the sort chips, and a
/// two-column grid of question cards. Matches Figma `group-4-prototype` 2A.
struct MemberBoardSection: View {
    @State private var viewModel: MemberBoardViewModel
    private let httpClient: HTTPClient

    /// How many questions to preview inline before "more+" takes over.
    private let previewLimit = 6

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
        _viewModel = State(initialValue: MemberBoardViewModel(programId: programId, httpClient: httpClient))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            BoardSortChips(selection: $viewModel.sort)
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
        .navigationDestination(for: MemberBoardLink.self) { link in
            MemberBoardFullView(programId: link.programId, httpClient: httpClient)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Member board")
                .font(.sectionHeader)
                .bold()
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            NavigationLink(value: MemberBoardLink(programId: viewModel.programId)) {
                Text("more+")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
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
            QuestionGrid(posts: Array(viewModel.sortedPosts.prefix(previewLimit)))
        }
    }
}

/// The single-select row of sort chips. Wraps to the next line on narrow
/// widths via `FlowLayout`.
struct BoardSortChips: View {
    @Binding var selection: BoardSort

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(BoardSort.allCases) { sort in
                Button {
                    withAnimation(.snappy) { selection = sort }
                } label: {
                    Text(sort.label)
                        .font(.buttonLabel)
                        .foregroundStyle(selection == sort ? Color.onBrand : Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selection == sort ? Color.brand : Color(.systemGray6),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == sort ? [.isSelected] : [])
            }
        }
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
                .font(.sectionHeader)
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

/// Full Member board reached via "more+": the same chips + grid, now showing
/// every question and scrollable on its own screen.
struct MemberBoardFullView: View {
    @State private var viewModel: MemberBoardViewModel
    @Environment(\.dismiss) private var dismiss
    private let horizontalPadding: CGFloat = 20

    init(programId: Int, httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MemberBoardViewModel(programId: programId, httpClient: httpClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Member board")
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)
                BoardSortChips(selection: $viewModel.sort)
                if viewModel.posts.isEmpty {
                    Text("No questions yet. Be the first to start a conversation.")
                        .font(.bodyText)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    QuestionGrid(posts: viewModel.sortedPosts)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.load()
            }
        }
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
