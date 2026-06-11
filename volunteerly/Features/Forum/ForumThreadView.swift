import SwiftUI

/// Question detail / forum thread. A chat-style layout: the question sits at the
/// top with its author (avatar + name) above a soft grey bubble, then a "Reply"
/// pill, then each comment as a chat message (avatar + name + time + bubble).
/// Matches Figma `group-4-prototype` node 147:360 (Question Page).
struct ForumThreadView: View {
    @State private var viewModel: ForumThreadViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composerFocused: Bool

    private let horizontalPadding: CGFloat = 24
    /// Leading inset that aligns a reply bubble under its author's name
    /// (avatar width + the gap between avatar and name).
    private let replyBubbleInset: CGFloat = 60

    init(post: ForumPost, currentUserId: Int = 1, httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(
            initialValue: ForumThreadViewModel(post: post, currentUserId: currentUserId, httpClient: httpClient)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.bottom, 28)

                questionHeader
                    .padding(.bottom, 18)

                questionBubble

                divider
                    .padding(.vertical, 18)

                replyComposer
                    .padding(.bottom, 18)

                divider
                    .padding(.bottom, 24)

                comments
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .alert(
            "Couldn't post",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.isLoading },
                set: { if !$0 { viewModel.clearError() } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: { message in
            Text(message)
        }
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

    /// The question's author — a 59pt avatar beside the bold name.
    private var questionHeader: some View {
        HStack(spacing: 20) {
            Avatar(url: viewModel.postAuthorImageURL, size: 59)
            Text(viewModel.postAuthorName)
                .font(.cardTitle)
                .foregroundStyle(Theme.iconPrimary)
        }
    }

    /// Full-width grey bubble holding the question text, italic and prefixed
    /// with "Q." to match the design.
    private var questionBubble: some View {
        Text(questionText)
            .font(.bodyText.italic())
            .foregroundStyle(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var questionText: String {
        let raw = viewModel.post.body.isEmpty ? viewModel.post.title : viewModel.post.body
        return raw.lowercased().hasPrefix("q.") ? raw : "Q. \(raw)"
    }

    /// Inline reply composer: a tappable text box the user types into, with the
    /// green "Reply" pill beneath it to post. Replaces the old bottom "Add a
    /// reply…" bar so the input lives right in the thread.
    private var replyComposer: some View {
        VStack(alignment: .trailing, spacing: 14) {
            TextField("Add a reply…", text: $viewModel.draft, axis: .vertical)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(4...10)
                .focused($composerFocused)
                .submitLabel(.return)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                // Make the whole box (not just the text line) focus the field.
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onTapGesture { composerFocused = true }

            replyButton
        }
    }

    /// Green pill that posts the typed reply.
    private var replyButton: some View {
        Button {
            viewModel.submitDraft()
            composerFocused = false
        } label: {
            Text("Reply")
                .font(.captionText)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Theme.brand300, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSubmit)
        .opacity(viewModel.canSubmit ? 1 : 0.5)
        .accessibilityLabel("Post reply")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
    }

    // MARK: Comments

    @ViewBuilder
    private var comments: some View {
        if viewModel.isLoading && viewModel.nodes.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if viewModel.nodes.isEmpty {
            Text("No replies yet. Tap Reply to start the conversation.")
                .font(.bodyText)
                .foregroundStyle(Theme.textMeta)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(flatten(viewModel.nodes)) { node in
                    ChatMessageRow(node: node, bubbleInset: replyBubbleInset)
                }
            }
        }
    }

    /// Depth-first flatten so nested replies render in the flat chat list right
    /// after their parent, matching the prototype's single-column thread.
    private func flatten(_ nodes: [CommentNode]) -> [CommentNode] {
        nodes.flatMap { [$0] + flatten($0.replies) }
    }

}

/// One chat message: a 40pt avatar with the author's name and timestamp on the
/// same row, then the message in a grey bubble indented under the name.
struct ChatMessageRow: View {
    let node: CommentNode
    let bubbleInset: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Avatar(url: node.authorImageURL, size: 40)
                Text(node.authorName)
                    .font(.bodyText)
                    .foregroundStyle(Theme.iconPrimary)
                Spacer(minLength: 8)
                Text(timeText(node.createdAt))
                    .font(.captionText.italic())
                    .foregroundStyle(Theme.black300)
            }

            Text(node.body)
                .font(.bodyText.italic())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.leading, bubbleInset)
        }
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        ForumThreadView(post: MockData.forumPosts[0], httpClient: MockHTTPClient.shared)
    }
}
