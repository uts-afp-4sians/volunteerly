import Foundation
import Observation

/// A comment plus its nested replies, ready to render recursively on the
/// forum thread screen.
struct CommentNode: Identifiable {
    let id: Int
    let authorUserId: Int
    var authorName: String
    var authorImageURL: URL?
    let body: String
    let createdAt: Date
    var likeCount: Int
    var isLiked: Bool
    var replies: [CommentNode]
}

/// Backs the question detail screen: loads the post's comments, builds the
/// reply tree, and handles like / reply / comment interactions.
///
/// The current API only exposes `GET …/comments`, so likes, replies and new
/// comments are applied to local state. The write paths are marked with
/// `TODO(oma-deferred)` to swap in real requests once the endpoints land.
@MainActor
@Observable
final class ForumThreadViewModel {
    let post: ForumPost

    private(set) var nodes: [CommentNode] = []
    private(set) var authorNames: [Int: String] = [:]
    private(set) var authorImages: [Int: URL] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Comment currently being replied to; `nil` means a new top-level comment.
    var replyingTo: CommentNode?
    var draft: String = ""

    var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Locally created comments use descending negative ids so they never
    /// collide with server ids.
    private var nextLocalId = -1

    private let httpClient: HTTPClient
    private let currentUserId: Int

    init(post: ForumPost, currentUserId: Int = 1, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.post = post
        self.currentUserId = currentUserId
        self.httpClient = httpClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let comments: [ForumComment] = try await httpClient.get(
                "/programs/\(post.programId)/posts/\(post.id)/comments"
            )
            await resolveAuthors(for: comments)
            nodes = buildTree(comments)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: Interactions

    /// Toggle the like on a comment anywhere in the tree. Applies the change
    /// optimistically, then reconciles with the server (reverting on failure).
    func toggleLike(_ id: Int) {
        guard let current = find(id, in: nodes) else { return }
        let nowLiked = !current.isLiked
        nodes = nodes.map { toggleLike($0, id: id) }
        Task { await syncLike(id: id, like: nowLiked) }
    }

    /// Aim the composer at `node` (or clear it for a top-level comment).
    func beginReply(to node: CommentNode?) {
        replyingTo = node
    }

    func cancelReply() {
        replyingTo = nil
    }

    /// Publish the draft as a reply (when `replyingTo` is set) or a new
    /// top-level comment. Inserts optimistically, then POSTs; on success the
    /// temporary node is swapped for the server's, on failure it's rolled back.
    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parentId = replyingTo?.id
        let tempId = nextLocalId
        nextLocalId -= 1
        let comment = CommentNode(
            id: tempId,
            authorUserId: currentUserId,
            authorName: authorNames[currentUserId] ?? "You",
            authorImageURL: authorImages[currentUserId],
            body: text,
            createdAt: .now,
            likeCount: 0,
            isLiked: false,
            replies: []
        )

        if let parentId {
            nodes = nodes.map { insert(comment, under: parentId, in: $0) }
        } else {
            nodes.append(comment)
        }

        draft = ""
        replyingTo = nil
        Task { await syncCreate(tempId: tempId, parentId: parentId, body: text) }
    }

    // MARK: Networking

    private var commentsPath: String {
        "/programs/\(post.programId)/posts/\(post.id)/comments"
    }

    private func syncLike(id: Int, like: Bool) async {
        let path = "\(commentsPath)/\(id)/like"
        do {
            // The optimistic toggle already reflects the new state; the request
            // just persists it. POST likes, DELETE unlikes. The decoded
            // response is ignored — the UI trusts its optimistic update and
            // self-corrects on the next load.
            if like {
                let _: ForumComment = try await httpClient.post(path, body: EmptyBody())
            } else {
                try await httpClient.delete(path)
            }
        } catch {
            // A parse failure means the request likely landed but we couldn't
            // read the echo — trust the optimistic toggle. Only a real
            // transport/auth/server error reverts and reports.
            guard !isResponseParseError(error) else { return }
            nodes = nodes.map { toggleLike($0, id: id) }
            errorMessage = error.localizedDescription
        }
    }

    private func syncCreate(tempId: Int, parentId: Int?, body: String) async {
        do {
            let created: ForumComment = try await httpClient.post(
                commentsPath, body: NewCommentBody(body: body, parentCommentId: parentId)
            )
            let server = makeNode(from: created)
            nodes = nodes.map { replace(tempId: tempId, with: server, in: $0) }
        } catch {
            // A parse failure means the comment likely persisted but we couldn't
            // read it back (e.g. the method-blind mock returns the list array) —
            // keep the optimistic node rather than dropping the user's text.
            // A real transport/auth/server error rolls back and reports.
            guard !isResponseParseError(error) else { return }
            nodes = nodes.compactMap { remove(id: tempId, from: $0) }
            errorMessage = error.localizedDescription
            draft = body
        }
    }

    /// Whether the error is a response-decoding failure (raw `DecodingError`
    /// from the mock, or `APIError.decodingFailed` from the live client) rather
    /// than a transport/auth/server error.
    private func isResponseParseError(_ error: Error) -> Bool {
        if error is DecodingError { return true }
        if case APIError.decodingFailed = error { return true }
        return false
    }

    // MARK: Tree helpers

    private func buildTree(_ comments: [ForumComment]) -> [CommentNode] {
        var childrenByParent: [Int: [ForumComment]] = [:]
        var roots: [ForumComment] = []
        for comment in comments {
            if let parent = comment.parentCommentId {
                childrenByParent[parent, default: []].append(comment)
            } else {
                roots.append(comment)
            }
        }

        func makeNode(_ comment: ForumComment) -> CommentNode {
            CommentNode(
                id: comment.id,
                authorUserId: comment.authorUserId,
                authorName: authorNames[comment.authorUserId] ?? "Member \(comment.authorUserId)",
                authorImageURL: authorImages[comment.authorUserId],
                body: comment.body,
                createdAt: comment.createdAt,
                likeCount: comment.likeCount ?? 0,
                isLiked: comment.likedByMe ?? false,
                replies: (childrenByParent[comment.id] ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                    .map(makeNode)
            )
        }

        return roots.sorted { $0.createdAt < $1.createdAt }.map(makeNode)
    }

    private func toggleLike(_ node: CommentNode, id: Int) -> CommentNode {
        var node = node
        if node.id == id {
            node.isLiked.toggle()
            node.likeCount = max(0, node.likeCount + (node.isLiked ? 1 : -1))
        }
        node.replies = node.replies.map { toggleLike($0, id: id) }
        return node
    }

    private func insert(_ child: CommentNode, under parentId: Int, in node: CommentNode) -> CommentNode {
        var node = node
        if node.id == parentId {
            node.replies.append(child)
        } else {
            node.replies = node.replies.map { insert(child, under: parentId, in: $0) }
        }
        return node
    }

    /// Depth-first lookup of a node by id.
    private func find(_ id: Int, in nodes: [CommentNode]) -> CommentNode? {
        for node in nodes {
            if node.id == id { return node }
            if let hit = find(id, in: node.replies) { return hit }
        }
        return nil
    }

    /// Swap an optimistic temp node for the server-created one (keeps replies).
    private func replace(tempId: Int, with server: CommentNode, in node: CommentNode) -> CommentNode {
        if node.id == tempId {
            var server = server
            server.replies = node.replies
            return server
        }
        var node = node
        node.replies = node.replies.map { replace(tempId: tempId, with: server, in: $0) }
        return node
    }

    /// Drop a node (and its subtree) by id, or `nil` if this node is the target.
    private func remove(id: Int, from node: CommentNode) -> CommentNode? {
        if node.id == id { return nil }
        var node = node
        node.replies = node.replies.compactMap { remove(id: id, from: $0) }
        return node
    }

    /// Build a render node from a single decoded comment (no nested replies).
    private func makeNode(from comment: ForumComment) -> CommentNode {
        CommentNode(
            id: comment.id,
            authorUserId: comment.authorUserId,
            authorName: authorNames[comment.authorUserId] ?? "You",
            authorImageURL: authorImages[comment.authorUserId],
            body: comment.body,
            createdAt: comment.createdAt,
            likeCount: comment.likeCount ?? 0,
            isLiked: comment.likedByMe ?? false,
            replies: []
        )
    }

    /// Resolve name + avatar for every author in the thread (plus the current
    /// user, so their own new comments are labelled). Missing profiles are
    /// non-fatal.
    private func resolveAuthors(for comments: [ForumComment]) async {
        let ids = Set(comments.map(\.authorUserId))
            .union([currentUserId])
            .subtracting(authorNames.keys)
        for id in ids {
            if let profile: UserProfile = try? await httpClient.get("/users/\(id)/profile") {
                authorNames[id] = profile.fullName
                if let raw = profile.profileImageURL, let url = URL(string: raw) {
                    authorImages[id] = url
                }
            }
        }
    }
}

// MARK: - Request bodies

/// Empty JSON body for POSTs whose inputs come entirely from the path + auth.
private struct EmptyBody: Encodable {}

/// Body for `POST …/comments` — `parent_comment_id` set makes it a reply.
private struct NewCommentBody: Encodable {
    let body: String
    let parentCommentId: Int?

    enum CodingKeys: String, CodingKey {
        case body
        case parentCommentId = "parent_comment_id"
    }
}
