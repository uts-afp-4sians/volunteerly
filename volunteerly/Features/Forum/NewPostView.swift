import SwiftUI

/// Compose sheet for opening a new Member board question. Presented from the
/// board's "Add post" link; submits via `MemberBoardViewModel.createPost`.
struct NewPostView: View {
    let viewModel: MemberBoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var postBody = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(title: "Title") {
                        TextField("What's your question?", text: $title)
                            .focused($titleFocused)
                    }
                    bodyField
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.bodyText)
                            .foregroundStyle(Color.fieldError)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await submit() } }
                            .font(.bodyStrong)
                            .foregroundStyle(canSubmit ? Theme.forest : Theme.textSecondary)
                            .disabled(!canSubmit)
                    }
                }
            }
            .task { titleFocused = true }
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
            TextEditor(text: $postBody)
                .font(.bodyText)
                .frame(minHeight: 160, alignment: .topLeading)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
            content()
                .font(.bodyText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

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
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NewPostView(
        viewModel: MemberBoardViewModel(programId: 1, httpClient: MockHTTPClient.shared)
    )
}
