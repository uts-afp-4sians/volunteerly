import SwiftUI

/// Question detail / forum thread. Shows the post title + description above a
/// threaded comment list where members can like, reply and add comments.
/// Matches Figma `group-4-prototype` 3A.
struct ForumThreadView: View {
    @State private var viewModel: ForumThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool

    private let horizontalPadding: CGFloat = 20

    init(post: ForumPost, currentUserId: Int = 1, httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(
            initialValue: ForumThreadViewModel(post: post, currentUserId: currentUserId, httpClient: httpClient)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                backButton
                question
                Divider().background(Theme.border)
                comments
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { composer }
        .task {
            if viewModel.nodes.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: Header

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.post.title)
                .font(.subheading)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.post.body)
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Comments

    @ViewBuilder
    private var comments: some View {
        if viewModel.isLoading && viewModel.nodes.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if viewModel.nodes.isEmpty {
            Text("No comments yet. Start the conversation below.")
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(viewModel.nodes) { node in
                    CommentThread(
                        node: node,
                        depth: 0,
                        onLike: { viewModel.toggleLike($0) },
                        onReply: { beginReply(to: $0) }
                    )
                }
            }
        }
    }

    // MARK: Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.border)
            if let target = viewModel.replyingTo {
                replyBanner(target)
            }
            HStack(spacing: 12) {
                TextField(composerPlaceholder, text: $viewModel.draft, axis: .vertical)
                    .font(.bodyText)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .submitLabel(.send)

                Button {
                    viewModel.submitDraft()
                    composerFocused = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.canSubmit ? Color.brand : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }

    private var composerPlaceholder: String {
        if let target = viewModel.replyingTo {
            return "Reply to \(target.authorName)…"
        }
        return "Add a comment…"
    }

    private func replyBanner(_ target: CommentNode) -> some View {
        HStack(spacing: 8) {
            Text("Replying to \(target.authorName)")
                .font(.buttonLabel)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Button {
                viewModel.cancelReply()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 8)
    }

    private func beginReply(to node: CommentNode) {
        viewModel.beginReply(to: node)
        composerFocused = true
    }
}

/// One comment and its nested replies, drawn recursively. Replies are indented
/// behind a thin vertical guide, mirroring the Figma thread.
struct CommentThread: View {
    let node: CommentNode
    let depth: Int
    let onLike: (Int) -> Void
    let onReply: (CommentNode) -> Void

    private var avatarSize: CGFloat { depth == 0 ? 44 : 40 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CommentRow(
                node: node,
                avatarSize: avatarSize,
                onLike: { onLike(node.id) },
                onReply: { onReply(node) }
            )

            if !node.replies.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(node.replies) { reply in
                            CommentThread(
                                node: reply,
                                depth: depth + 1,
                                onLike: onLike,
                                onReply: onReply
                            )
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}

/// A single comment line: avatar, author + body, a Reply affordance and a
/// like (thumbs-up) toggle.
struct CommentRow: View {
    let node: CommentNode
    let avatarSize: CGFloat
    let onLike: () -> Void
    let onReply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(url: node.authorImageURL, size: avatarSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.authorName)
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
                Text(node.body)
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onReply) {
                    Text("Reply")
                        .font(.buttonLabel)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            Spacer(minLength: 8)

            likeButton
        }
    }

    private var likeButton: some View {
        Button(action: onLike) {
            HStack(spacing: 4) {
                if node.likeCount > 0 {
                    Text("\(node.likeCount)")
                        .font(.buttonLabel)
                        .foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: node.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 18))
                    .foregroundStyle(node.isLiked ? Color.brand : Theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(node.isLiked ? "Unlike" : "Like")
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ForumThreadView(post: MockData.forumPosts[0], httpClient: MockHTTPClient.shared)
    }
}
