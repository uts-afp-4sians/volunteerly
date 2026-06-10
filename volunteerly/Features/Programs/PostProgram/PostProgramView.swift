import SwiftUI
import Combine
import MapKit
import CoreLocation
import PhotosUI

struct PostProgramView: View {
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: PostProgramViewModel
    /// Called after a program is successfully saved (create OR edit) so the
    /// caller can refresh feeds / pop the detail.
    private let onCreated: () -> Void

    init(
        httpClient: HTTPClient = LiveHTTPClient.shared,
        onCreated: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: PostProgramViewModel(httpClient: httpClient))
        self.onCreated = onCreated
    }

    /// Edit-mode initialiser — pre-populates the form from an existing program
    /// and switches `submit()` to PATCH /programs/{id}.
    init(
        editing program: Program,
        httpClient: HTTPClient = LiveHTTPClient.shared,
        onCreated: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: PostProgramViewModel(editing: program, httpClient: httpClient))
        self.onCreated = onCreated
    }

    // Up to three program photos (Figma 190:639 "Add images"). The first picked
    // photo doubles as the program banner — its bytes are pushed to the view
    // model and uploaded to R2 on submit.
    let maxPhotos = 3
    @State var photoItems: [PhotosPickerItem] = []
    @State var photoImages: [Image] = []
    /// iOS home-screen-style "edit mode": long-pressing a thumbnail makes the
    /// row jiggle and reveals a per-photo delete badge.
    @State var photosEditing = false

    // UI State
    @State private var activeSheet: SheetType? = nil
    /// Confirm before discarding unsaved edits when the user backs out / swipes.
    @State private var showDiscardConfirm = false

    enum SheetType: Identifiable {
        case location
        case startDate
        case startTime
        case endDate
        case endTime
        case repeatSelection

        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                    // 1. Category
                    categorySelectorRow

                    // 2. Program Name
                    nameField

                    // 3. Description
                    descriptionField

                    // 4. Location
                    locationInput

                    // 5. Date
                    dateSection

                    // 6. Volunteers Needed
                    volunteersSliderSection

                    // 7. Add images (up to three; the first is the banner, uploaded to R2)
                    imageSection

                    // 9. Commitment (optional)
                    commitmentFrequencyField
                    commitmentDurationField

                    // Submit button
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.pageBackground)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            if photosEditing {
                withAnimation(.easeInOut(duration: 0.2)) { photosEditing = false }
            }
        }
        .task {
            if viewModel.categories.isEmpty { await viewModel.loadCategories() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .interactiveSwipeBack(
            canPop: { !viewModel.isDirty },
            onBlocked: { showDiscardConfirm = true }
        )
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.isDirty {
                        showDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            // Figma 190:639: "Post Program" is a 30pt regular title (.subheading),
            // centered, not the default ~17pt inline title.
            ToolbarItem(placement: .principal) {
                Text("Post Program")
                    .font(.subheading)
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .alert(
            "Couldn't post program",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            "Discard this program?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your changes won't be saved.")
        }
        .sheet(item: $activeSheet) { type in
            switch type {
            case .startDate:
                // Calendar sheet — tapping the "Starts" date chip (Figma 358:967).
                DateSelectionView(date: $viewModel.startDate)
                    .presentationDetents([.height(560)])
                    .presentationDragIndicator(.hidden)
            case .startTime:
                // Time wheel sheet — tapping the "Starts" time chip (Figma 329:1550).
                TimeSelectionView(date: $viewModel.startDate)
                    .presentationDetents([.height(440)])
                    .presentationDragIndicator(.hidden)
            case .endDate:
                DateSelectionView(date: $viewModel.endDate, minimumDate: viewModel.startDate)
                    .presentationDetents([.height(560)])
                    .presentationDragIndicator(.hidden)
            case .endTime:
                TimeSelectionView(date: $viewModel.endDate, minimumDate: viewModel.startDate)
                    .presentationDetents([.height(440)])
                    .presentationDragIndicator(.hidden)
            case .location:
                // The location sheet carries its own centered title + custom
                // blue drag handle (Figma 226:685), so it isn't wrapped in
                // navSheet.
                LocationSelectionSheet(
                    picked: $viewModel.pickedLocation,
                    regionName: $viewModel.selectedRegion
                )
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.hidden)
            case .repeatSelection:
                // The reoccurrence sheet carries its own title + custom blue
                // drag handle (Figma 329:1821), so it isn't wrapped in navSheet.
                RepeatSelectionView(selectedRepeat: $viewModel.selectedRepeat)
                    .presentationDetents([.height(520)])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    /// Wraps a sheet in a navigation stack with a trailing "Close" button.
    /// The date sheet skips this — it matches the Figma chrome-less calendar
    /// (drag handle + Confirm) instead.
    @ViewBuilder
    private func navSheet<Content: View>(
        detents: Set<PresentationDetent>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            activeSheet = nil
                        }
                    }
                }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sheet routing

    /// Opens one of the date/time/location/repeat sheets. Passed into the
    /// section builders so they don't need to mutate `activeSheet` directly.
    func presentSheet(_ type: SheetType) {
        activeSheet = type
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task {
                if await viewModel.submit() {
                    onCreated()
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView().tint(Color.onBrand)
                } else {
                    Text("Post").font(.bodyStrong)
                }
            }
            .foregroundStyle(Color.onBrand)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.brand, in: RoundedRectangle(cornerRadius: 25))
            .opacity(viewModel.canSubmit ? 1.0 : 0.6)
        }
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.plain)
        .padding(.top, 10)
    }

    // MARK: - Photo picker plumbing

    /// Decode the picked items into displayable images, preserving pick order.
    /// All photos (up to `maxPhotos`) are uploaded as the program's banner
    /// gallery on submit; the first doubles as the legacy single banner.
    func loadPhotos(_ items: [PhotosPickerItem]) async {
        var images: [Image] = []
        var photoData: [Data] = []
        for item in items.prefix(maxPhotos) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }
            photoData.append(data)
            images.append(Image(uiImage: uiImage))
        }
        photoImages = images
        viewModel.bannerImageData = photoData
    }

    func removePhoto(at index: Int) {
        guard index < photoItems.count else { return }
        photoItems.remove(at: index)
        if index < photoImages.count {
            photoImages.remove(at: index)
        }
    }
}

#Preview {
    let _ = MockData.registerAll(in: MockHTTPClient.shared)
    return NavigationStack {
        PostProgramView(httpClient: MockHTTPClient.shared)
    }
}
