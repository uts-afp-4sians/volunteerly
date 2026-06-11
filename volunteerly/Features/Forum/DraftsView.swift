import PhotosUI
import SwiftUI

/// The Drafts browser: a two-column grid of the board drafts saved for a program
/// (capped at three). Tapping a card opens `DraftDetailView`; the green pencil
/// in each card's bottom-right corner opens the in-place `DraftEditOverlay`. The
/// leading arrow dismisses back to the composer. Matches Figma
/// `group-4-prototype` node 329-605 (left frame) + 605-811 (edit overlay).
struct DraftsView: View {
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    /// Called when an in-place edit is saved, so the host can persist it.
    let onSaved: (PostDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [PostDraft]
    @State private var editingDraft: PostDraft?

    init(
        drafts: [PostDraft],
        viewModel: MemberBoardViewModel,
        onPosted: @escaping (PostDraft) -> Void,
        onSaved: @escaping (PostDraft) -> Void
    ) {
        _drafts = State(initialValue: drafts)
        self.viewModel = viewModel
        self.onPosted = onPosted
        self.onSaved = onSaved
    }

    private let columns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if drafts.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .draftEditOverlay(
            editing: $editingDraft,
            viewModel: viewModel,
            onPosted: onPosted,
            onSaved: handleSaved
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Drafts")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 11) {
            ForEach(drafts) { draft in
                // The card opens the preview; the pencil opens the edit overlay.
                // Siblings (not nested) so each owns its own hit area.
                ZStack(alignment: .bottomTrailing) {
                    NavigationLink {
                        DraftDetailView(
                            draft: draft,
                            viewModel: viewModel,
                            onPosted: onPosted,
                            onSaved: handleSaved
                        )
                    } label: {
                        DraftCard(draft: draft)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { editingDraft = draft }
                    } label: {
                        editPencil
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("Edit draft")
                }
            }
        }
    }

    /// Green circular pencil overlaying a card's bottom-right corner.
    private var editPencil: some View {
        Image(systemName: "pencil")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.onBrand)
            .frame(width: 28, height: 28)
            .background(Theme.brandPrimary, in: Circle())
    }

    private var emptyState: some View {
        Text("No saved drafts yet. Save one from the composer and it'll show up here.")
            .font(.bodyText)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    /// Persist a saved edit locally (so the grid refreshes) and bubble it up.
    private func handleSaved(_ saved: PostDraft) {
        if let index = drafts.firstIndex(where: { $0.id == saved.id }) {
            drafts[index] = saved
        }
        onSaved(saved)
    }
}

/// A single draft tile: its title over its description on a soft grey card,
/// mirroring the Member board's `QuestionCard`.
struct DraftCard: View {
    let draft: PostDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.title.isEmpty ? "Untitled draft" : draft.title)
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(draft.body.isEmpty ? "No description" : draft.body)
                .font(.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 163, maxHeight: 163, alignment: .topLeading)
        .padding(16)
        .background(Color(.systemGray6))
    }
}

/// A draft preview: its title and description above an image placeholder, with
/// a floating pencil that opens the draft in `DraftEditOverlay` for editing.
/// Matches Figma `group-4-prototype` node 329-605 (right frame).
struct DraftDetailView: View {
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    let onSaved: (PostDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PostDraft
    @State private var editingDraft: PostDraft?

    private let horizontalPadding: CGFloat = 20

    init(
        draft: PostDraft,
        viewModel: MemberBoardViewModel,
        onPosted: @escaping (PostDraft) -> Void,
        onSaved: @escaping (PostDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.viewModel = viewModel
        self.onPosted = onPosted
        self.onSaved = onSaved
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    backRow
                    draftContent
                    divider
                    Spacer(minLength: 130)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractiveSwipeBack()
        .overlay(alignment: .bottomTrailing) { editButton }
        .draftEditOverlay(
            editing: $editingDraft,
            viewModel: viewModel,
            onPosted: onPosted,
            onSaved: handleSaved
        )
    }

    private var backRow: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text("Draft Title")
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
    }

    private var draftContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(draft.title.isEmpty ? "Question" : draft.title)
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 28)

            Text(draft.body.isEmpty ? "Description" : draft.body)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)

            imagePlaceholder
                .padding(.top, 19)
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(.systemGray6))
            .frame(height: 253)
            .overlay {
                Image(systemName: "camera.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(Color(.systemGray3))
            }
    }

    private var divider: some View {
        Divider()
            .padding(.top, 132)
    }

    private var editButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { editingDraft = draft }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 37, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 87, height: 87)
                .background(Color(.systemGray6), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 36)
        .padding(.bottom, 36)
        .accessibilityLabel("Edit draft")
    }

    /// Reflect the saved edit in this preview, then bubble it up.
    private func handleSaved(_ saved: PostDraft) {
        draft = saved
        onSaved(saved)
    }
}

// MARK: - Edit overlay

private extension View {
    /// Presents `DraftEditOverlay` as a dimmed modal card whenever `editing`
    /// holds a draft. Clearing the binding dismisses it.
    func draftEditOverlay(
        editing: Binding<PostDraft?>,
        viewModel: MemberBoardViewModel,
        onPosted: @escaping (PostDraft) -> Void,
        onSaved: @escaping (PostDraft) -> Void
    ) -> some View {
        overlay {
            if let draft = editing.wrappedValue {
                DraftEditOverlay(
                    draft: draft,
                    viewModel: viewModel,
                    onPosted: { posted in
                        editing.wrappedValue = nil
                        onPosted(posted)
                    },
                    onSaved: { saved in
                        onSaved(saved)
                        withAnimation(.easeOut(duration: 0.2)) { editing.wrappedValue = nil }
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) { editing.wrappedValue = nil }
                    }
                )
                .transition(.opacity)
            }
        }
    }
}

/// In-place draft editor presented as a centred modal card over a dimmed scrim.
/// The title and description are editable; "Save draft" persists the edit and
/// "Post" publishes it. Matches Figma `group-4-prototype` node 605-811.
struct DraftEditOverlay: View {
    let draft: PostDraft
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    let onSaved: (PostDraft) -> Void
    let onClose: () -> Void

    @State private var title: String
    @State private var postBody: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    init(
        draft: PostDraft,
        viewModel: MemberBoardViewModel,
        onPosted: @escaping (PostDraft) -> Void,
        onSaved: @escaping (PostDraft) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.draft = draft
        self.viewModel = viewModel
        self.onPosted = onPosted
        self.onSaved = onSaved
        self.onClose = onClose
        _title = State(initialValue: draft.title)
        _postBody = State(initialValue: draft.body)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedBody: String { postBody.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedTitle.isEmpty || !trimmedBody.isEmpty }
    private var canPost: Bool { !trimmedTitle.isEmpty && !trimmedBody.isEmpty && !isSubmitting }

    var body: some View {
        ZStack {
            // Scrim (Figma 605:829 — black 30%). Tapping outside dismisses.
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            card
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
        }
        .alert(
            "Couldn't post",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            closeButton

            TextField("Draft Question", text: $title, axis: .vertical)
                .font(.sectionTitle)
                .tracking(-0.3)
                .foregroundStyle(Color.black900)
                .focused($focus, equals: .title)
                .padding(.top, 12)

            TextField("Description", text: $postBody, axis: .vertical)
                .font(.bodyText)
                .foregroundStyle(Theme.textBody)
                .focused($focus, equals: .body)
                .padding(.top, 10)

            imageUpload
                .padding(.top, 22)

            buttonRow
                .padding(.top, 24)
        }
        .padding(24)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
    }

    private var closeButton: some View {
        Button { onClose() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.iconPrimary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var imageUpload: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surface)
                if let photoImage {
                    photoImage
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Theme.black300)
                        Text("Tap to upload image")
                            .font(.subheadText)
                            .foregroundStyle(Theme.black500)
                    }
                }
            }
            .frame(height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 12) {
            // Save draft — outlined, hugs its label.
            Button { saveDraft() } label: {
                Text("Save draft")
                    .font(.buttonLabel)
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(Capsule().stroke(Color.brand, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)

            // Post — filled, takes the remaining width.
            Button { Task { await postDraft() } } label: {
                ZStack {
                    if isSubmitting {
                        ProgressView().tint(Color.onBrand)
                    } else {
                        Text("Post").font(.buttonLabel)
                    }
                }
                .foregroundStyle(Color.onBrand)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
            .opacity(canPost ? 1 : 0.5)
        }
    }

    private func saveDraft() {
        var updated = draft
        updated.title = title
        updated.body = postBody
        onSaved(updated)
    }

    private func postDraft() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        if await viewModel.createPost(title: title, body: postBody) {
            onPosted(draft)
        } else {
            errorMessage = viewModel.errorMessage ?? "Couldn't post your question. Please try again."
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        photoImage = Image(uiImage: uiImage)
        // TODO(oma-deferred): upload the image once the posts API accepts media;
        // `createPost` has no image parameter yet, so the pick is preview-only.
    }
}

#Preview("Drafts") {
    NavigationStack {
        DraftsView(
            drafts: [
                PostDraft(title: "Best moment from the cleanup?", body: "Share a highlight from last weekend's beach cleanup."),
                PostDraft(title: "Ride share to the shelter", body: "Anyone driving from downtown on Saturday morning?"),
                PostDraft(title: "", body: "")
            ],
            viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared),
            onPosted: { _ in },
            onSaved: { _ in }
        )
    }
}

#Preview("Draft detail") {
    NavigationStack {
        DraftDetailView(
            draft: PostDraft(title: "Best moment from the cleanup?", body: "Share a highlight from last weekend's beach cleanup so newcomers know what to expect."),
            viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared),
            onPosted: { _ in },
            onSaved: { _ in }
        )
    }
}

#Preview("Draft edit overlay") {
    DraftEditOverlay(
        draft: PostDraft(title: "Draft Question", body: "Description"),
        viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared),
        onPosted: { _ in },
        onSaved: { _ in },
        onClose: {}
    )
}
