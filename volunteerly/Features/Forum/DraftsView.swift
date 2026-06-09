import SwiftUI

/// The Drafts browser: a two-column grid of the board drafts saved for a program
/// (capped at three). Tapping a card opens `DraftDetailView`; the leading arrow
/// dismisses back to the composer. Matches Figma `group-4-prototype` node
/// 329-605 (left frame).
struct DraftsView: View {
    let drafts: [PostDraft]
    /// Invoked when the user opens a draft for editing (the detail's pencil).
    /// The composer reloads the draft and this browser closes.
    let onEdit: (PostDraft) -> Void
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
                NavigationLink {
                    DraftDetailView(draft: draft) { onEdit(draft) }
                } label: {
                    DraftCard(draft: draft)
                }
                .buttonStyle(.plain)
            }
        }
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
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A draft preview: its title and description above an image placeholder, with
/// a floating pencil that reopens the draft in the composer for editing.
/// Matches Figma `group-4-prototype` node 329-605 (right frame).
struct DraftDetailView: View {
    let draft: PostDraft
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let horizontalPadding: CGFloat = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                backRow
                content
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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

            Text(draft.title.isEmpty ? "Untitled draft" : draft.title)
                .font(.pageTitle)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
    }

    private var content: some View {
        Text(draft.body.isEmpty ? "No description yet" : draft.body)
            .font(.bodyText)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 56, height: 56)
                .background(Color(.systemGray6), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .accessibilityLabel("Edit draft")
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
            onEdit: { _ in }
        )
    }
}

#Preview("Draft detail") {
    NavigationStack {
        DraftDetailView(
            draft: PostDraft(title: "Best moment from the cleanup?", body: "Share a highlight from last weekend's beach cleanup so newcomers know what to expect."),
            onEdit: {}
        )
    }
}
