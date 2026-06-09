import PhotosUI
import SwiftUI

/// The "New post" page, pushed from the Member board's "Add post" link.
/// Matches Figma `group-4-prototype` node 329-501: a title, a drafts chip,
/// Title + Description fields with character limits, an image upload area, and
/// a Post / Save draft button row. Submits via `MemberBoardViewModel.createPost`.
struct NewPostView: View {
    let viewModel: MemberBoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var postBody = ""
    @State private var drafts: [PostDraft] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let titleLimit = 60
    private let titleMinimum = 3
    private let bodyLimit = 500

    private var titleValid: Bool {
        let count = title.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count >= titleMinimum && title.count <= titleLimit
    }

    /// The Title helper line: an over-limit warning, a minimum-length warning
    /// once the user has started typing, or the neutral character hint.
    private var titleHelper: (text: String, isError: Bool) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.count > titleLimit {
            return ("Keep it under \(titleLimit) characters", true)
        }
        if !trimmed.isEmpty && trimmed.count < titleMinimum {
            return ("Title needs to be at least \(titleMinimum) characters", true)
        }
        return ("Up to \(titleLimit) characters", false)
    }

    private var bodyValid: Bool {
        let count = postBody.trimmingCharacters(in: .whitespacesAndNewlines).count
        return count > 0 && postBody.count <= bodyLimit
    }

    private var canPost: Bool { titleValid && bodyValid && !isSubmitting }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("New post")
                    .font(.pageTitle)
                    .foregroundStyle(Theme.textPrimary)

                draftsChip
                titleSection
                descriptionSection
                imageSection

                if let errorMessage {
                    Text(errorMessage)
                        .font(.buttonLabel)
                        .foregroundStyle(Color.fieldError)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { actionBar }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { drafts = ForumDraftStore.load(programId: viewModel.programId) }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    // MARK: Drafts chip

    private var draftsChip: some View {
        Button {
            restoreLatestDraft()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 14))
                Text("Drafts \(drafts.count)")
                    .font(.bodyText)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(drafts.isEmpty)
        .opacity(drafts.isEmpty ? 0.6 : 1)
        .accessibilityLabel("Drafts")
        .accessibilityValue("\(drafts.count) saved")
    }

    // MARK: Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Title")
            TextField("e.g. Best moment from your last event", text: $title)
                .font(.bodyText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            helper(text: titleHelper.text, isError: titleHelper.isError)
        }
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Description")
            TextEditor(text: $postBody)
                .font(.bodyText)
                .frame(minHeight: 120, alignment: .topLeading)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if postBody.isEmpty {
                        Text("Share what's on your mind...")
                            .font(.bodyText)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
            HStack(alignment: .firstTextBaseline) {
                if postBody.count > bodyLimit {
                    helper(text: "Keep it under \(bodyLimit) characters", isError: true)
                }
                Spacer(minLength: 8)
                Text("\(postBody.count)/\(bodyLimit)")
                    .font(.buttonLabel)
                    .foregroundStyle(postBody.count > bodyLimit ? Color.fieldError : Theme.textPrimary)
            }
        }
    }

    // MARK: Add images

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Add images")
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                    if let photoImage {
                        photoImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Tap to upload\nimage")
                                .font(.labelItalic)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        let canSaveDraft = titleValid || bodyValid
        return HStack(spacing: 16) {
            // Save draft — outlined, hugs its label.
            Button { saveDraft() } label: {
                Text("Save draft")
                    .font(.bodyStrong)
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 28)
                    .frame(height: 56)
                    .background(Capsule().stroke(Color.brand, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(!canSaveDraft)
            .opacity(canSaveDraft ? 1 : 0.5)

            // Post — filled, takes the remaining width.
            Button { Task { await submit() } } label: {
                ZStack {
                    if isSubmitting {
                        ProgressView().tint(Color.onBrand)
                    } else {
                        Text("Post").font(.bodyStrong)
                    }
                }
                .foregroundStyle(Color.onBrand)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
            .opacity(canPost ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    // MARK: Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.bodyStrong)
            .foregroundStyle(Theme.textPrimary)
    }

    private func helper(text: String, isError: Bool) -> some View {
        Text(text)
            .font(.buttonLabel)
            .foregroundStyle(isError ? Color.fieldError : Theme.textSecondary)
    }

    // MARK: Actions

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let created = await viewModel.createPost(title: title, body: postBody)
        if created {
            dismiss()
        } else {
            errorMessage = viewModel.errorMessage ?? "Couldn't post your question. Please try again."
        }
    }

    private func saveDraft() {
        let draft = PostDraft(title: title, body: postBody)
        drafts.append(draft)
        ForumDraftStore.save(drafts, programId: viewModel.programId)
        dismiss()
    }

    /// Pull the most recent draft back into the fields and drop it from the
    /// store, so tapping the chip resumes where the user left off.
    private func restoreLatestDraft() {
        guard let latest = drafts.last else { return }
        title = latest.title
        postBody = latest.body
        drafts.removeLast()
        ForumDraftStore.save(drafts, programId: viewModel.programId)
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

/// A locally-stored Member board draft. Persisted per program in
/// `UserDefaults` — there is no drafts endpoint on the API yet.
struct PostDraft: Codable, Identifiable {
    var id = UUID()
    var title: String
    var body: String
}

/// Per-program draft persistence backed by `UserDefaults`.
/// TODO(oma-deferred): move drafts server-side once a drafts API exists.
enum ForumDraftStore {
    private static func key(_ programId: Int) -> String { "forum_drafts_\(programId)" }

    static func load(programId: Int) -> [PostDraft] {
        guard let data = UserDefaults.standard.data(forKey: key(programId)),
              let drafts = try? JSONDecoder().decode([PostDraft].self, from: data) else {
            return []
        }
        return drafts
    }

    static func save(_ drafts: [PostDraft], programId: Int) {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        UserDefaults.standard.set(data, forKey: key(programId))
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        NewPostView(
            viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared)
        )
    }
}
