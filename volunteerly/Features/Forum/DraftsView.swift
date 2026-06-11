import PhotosUI
import SwiftUI

/// The Drafts browser: a two-column grid of the board drafts saved for a program
/// (capped at three). Tapping a card opens `DraftDetailView`; the green pencil
/// in each card's bottom-right corner jumps straight to `DraftEditView`. The
/// leading arrow dismisses back to the composer. Matches Figma
/// `group-4-prototype` node 329-605 (left frame).
struct DraftsView: View {
    let drafts: [PostDraft]
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    @Environment(\.dismiss) private var dismiss

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
                // Two sibling links: the card opens the preview, the pencil
                // jumps straight to editing. Siblings (not nested) so each
                // owns its own hit area.
                ZStack(alignment: .bottomTrailing) {
                    NavigationLink {
                        DraftDetailView(
                            draft: draft,
                            viewModel: viewModel,
                            onPosted: onPosted
                        )
                    } label: {
                        DraftCard(draft: draft)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DraftEditView(
                            draft: draft,
                            viewModel: viewModel,
                            onPosted: onPosted
                        )
                    } label: {
                        editPencil
                    }
                    .buttonStyle(.plain)
                    .padding(10)
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
            .accessibilityLabel("Edit draft")
    }

    private var emptyState: some View {
        Text("No saved drafts yet. Save one from the composer and it'll show up here.")
            .font(.bodyText)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
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
/// a floating pencil that reopens the draft in the composer for editing.
/// Matches Figma `group-4-prototype` node 329-605 (right frame).
struct DraftDetailView: View {
    let draft: PostDraft
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    private let horizontalPadding: CGFloat = 20

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
        NavigationLink {
            DraftEditView(
                draft: draft,
                viewModel: viewModel,
                onPosted: onPosted
            )
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
}

/// Editable draft preview matching Figma node 398:1260. The title,
/// description and optional image are edited in place before posting.
struct DraftEditView: View {
    let draft: PostDraft
    let viewModel: MemberBoardViewModel
    let onPosted: (PostDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var postBody: String
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDiscardConfirm = false

    init(
        draft: PostDraft,
        viewModel: MemberBoardViewModel,
        onPosted: @escaping (PostDraft) -> Void
    ) {
        self.draft = draft
        self.viewModel = viewModel
        self.onPosted = onPosted
        _title = State(initialValue: draft.title)
        _postBody = State(initialValue: draft.body)
    }

    private var isDirty: Bool {
        title != draft.title || postBody != draft.body || photoItem != nil
    }

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    backRow
                    editableContent
                    divider
                    Spacer(minLength: 130)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { postButton }
        .interactiveSwipeBack(
            canPop: { !isDirty },
            onBlocked: { showDiscardConfirm = true }
        )
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .confirmationDialog(
            "Discard changes to this draft?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your changes won't be saved.")
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

    private var backRow: some View {
        HStack(spacing: 16) {
            Button { attemptDismiss() } label: {
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

    private var editableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Question", text: $title, axis: .vertical)
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 28)

            TextField("Description", text: $postBody, axis: .vertical)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 3)

            PhotosPicker(selection: $photoItem, matching: .images) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemGray6))
                    .frame(height: 253)
                    .overlay {
                        if let photoImage {
                            photoImage
                                .resizable()
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36, weight: .regular))
                                .foregroundStyle(Color(.systemGray3))
                        }
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 19)
        }
    }

    private var divider: some View {
        Divider()
            .padding(.top, 132)
    }

    private var postButton: some View {
        Button {
            Task { await postDraft() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView().tint(Theme.onBrand)
                } else {
                    Text("Post")
                        .font(.buttonLabel)
                }
            }
            .foregroundStyle(Theme.onBrand)
            .frame(maxWidth: .infinity)
            .frame(height: 53)
            .background(Theme.forest, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canPost)
        .opacity(canPost ? 1 : 0.5)
        .padding(.horizontal, 21)
        .padding(.bottom, 22)
        .background(Theme.background)
    }

    private func attemptDismiss() {
        if isDirty {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func postDraft() async {
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
            onPosted: { _ in }
        )
    }
}

#Preview("Draft detail") {
    NavigationStack {
        DraftDetailView(
            draft: PostDraft(title: "Best moment from the cleanup?", body: "Share a highlight from last weekend's beach cleanup so newcomers know what to expect."),
            viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared),
            onPosted: { _ in }
        )
    }
}
