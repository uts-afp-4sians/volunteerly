import SwiftUI

struct BookmarksView: View {
    @State private var viewModel: MyPageViewModel

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        _viewModel = State(initialValue: MyPageViewModel(httpClient: httpClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VolunteerlyHeader()

                Text("Bookmarks")
                    .font(.pageTitle)
                    .foregroundStyle(Color.textPrimary)

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.programs.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.programs.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Something went wrong",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding(.top, 40)
        } else if viewModel.bookmarkPrograms.isEmpty {
            ContentUnavailableView("No bookmarks yet", systemImage: "bookmark")
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 23) {
                ForEach(viewModel.bookmarkPrograms) { program in
                    NavigationLink(value: program.id) {
                        BookmarkRow(program: program)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Compact bookmark list row — a 69×69 rounded thumbnail beside the program
/// name, vertically centred. Matches the Bookmarks design (Figma `390:1030`).
private struct BookmarkRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 17) {
            AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(.systemGray6))
            }
            .frame(width: 69, height: 69)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(program.name)
                .font(.bodyStrong)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        BookmarksView(httpClient: MockHTTPClient.shared)
    }
    .environment(TabRouter())
}
