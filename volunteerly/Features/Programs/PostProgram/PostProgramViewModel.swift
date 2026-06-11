import Foundation
import Observation

@MainActor
@Observable
final class PostProgramViewModel {
    // MARK: - Form state

    /// Default volunteer headcount shown on a fresh form (mockup value). Also the
    /// baseline `isDirty` compares against, so it lives in one place.
    static let defaultMaxVolunteers = 7
    /// Category selected on a fresh form, before `loadCategories` may rebase it.
    static let defaultCategoryId = 1

    var name: String = ""
    var selectedCategoryId: Int = PostProgramViewModel.defaultCategoryId
    var description: String = ""
    var maxVolunteers: Int = PostProgramViewModel.defaultMaxVolunteers
    var commitmentFrequency: CommitmentFrequency?
    var commitmentDuration: CommitmentDuration?

    /// Banner image bytes in pick order, decoded by the picker in the view and
    /// uploaded to R2 on submit (up to three; the first is the banner). The
    /// preview `Image`s stay view-side since they aren't submitted.
    var bannerImageData: [Data] = []

    /// Banner URLs already saved on the program being edited, shown as
    /// thumbnails so the host sees the current images. The host can delete from
    /// this set; surviving entries are merged with freshly uploaded picks on
    /// submit. Empty in create mode.
    var existingImageURLs: [String] = []

    /// Whether the host has actually changed the images while editing — a saved
    /// image was removed, or new photos were picked. Derived (not a sticky flag)
    /// so undoing every change flips it back to false: `submit()` then leaves
    /// both image fields nil and the backend keeps the saved gallery untouched.
    var imagesEdited: Bool {
        existingImageURLs != originalImageURLs || !bannerImageData.isEmpty
    }

    /// Snapshot of the saved gallery captured at edit-init, the baseline
    /// `imagesEdited` compares against. Empty in create mode.
    private let originalImageURLs: [String]

    // MARK: - Details

    var selectedRegion: String = ""
    /// Structured pick from the location sheet; resolved to a backend
    /// `location_id` at submit time. `selectedRegion` mirrors its display name.
    var pickedLocation: PickedLocation?
    var startDate: Date
    var endDate: Date
    var selectedRepeat: String = "Never" // Default recurrence (Figma 329:1821)

    // MARK: - Network-backed state

    var categories: [ProgramCategory] = []
    var isLoadingCategories = false
    var isSubmitting = false
    var errorMessage: String?

    /// Set when the form is editing an existing program. `nil` means create
    /// mode (POST), otherwise `submit()` issues a PATCH against this id.
    let editingProgramId: Int?

    var isEditing: Bool { editingProgramId != nil }

    var canSubmit: Bool {
        !name.isEmpty && !description.isEmpty && selectedCategoryId != 0 && !isSubmitting
    }

    /// True once the user has touched any field, so the view can confirm before
    /// discarding unsaved edits on back/swipe. Compared against the form's
    /// initial state (dates and category baseline captured at load).
    var isDirty: Bool {
        !name.isEmpty
            || !description.isEmpty
            || !selectedRegion.isEmpty
            || imagesEdited
            || maxVolunteers != Self.defaultMaxVolunteers
            || commitmentFrequency != nil
            || commitmentDuration != nil
            || selectedRepeat != "Never"
            || startDate != initialStartDate
            || endDate != initialEndDate
            || selectedCategoryId != baselineCategoryId
    }

    /// Form baselines for `isDirty`. Dates are fixed at init; the category
    /// baseline is rebased after `loadCategories` resolves the default selection.
    private let initialStartDate: Date
    private let initialEndDate: Date
    private var baselineCategoryId: Int

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
        self.editingProgramId = nil
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let end = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now)
            ?? now.addingTimeInterval(3600)
        startDate = start
        endDate = end
        initialStartDate = start
        initialEndDate = end
        baselineCategoryId = Self.defaultCategoryId
        originalImageURLs = []
    }

    /// Initialise the form pre-populated for editing an existing program.
    /// `submit()` will PATCH the changes back to the same `program.id`.
    init(editing program: Program, httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
        self.editingProgramId = program.id
        self.name = program.name
        self.selectedCategoryId = program.categoryId
        self.description = program.description
        self.maxVolunteers = program.maxVolunteers
        self.commitmentFrequency = program.commitmentFrequency
        self.commitmentDuration = program.commitmentDuration
        self.startDate = program.startDatetime
        self.endDate = program.endDatetime
        self.existingImageURLs = program.galleryImageURLs
        self.originalImageURLs = program.galleryImageURLs
        // Baselines mirror the prefilled values so `isDirty`'s date/category
        // checks only fire on actual edits.
        initialStartDate = program.startDatetime
        initialEndDate = program.endDatetime
        baselineCategoryId = program.categoryId
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }
        do {
            let cats: [ProgramCategory] = try await httpClient.get("/categories")
            categories = cats
            if let first = cats.first,
               !cats.contains(where: { $0.id == selectedCategoryId }) {
                selectedCategoryId = first.id
            }
            // Rebase so the auto-resolved default category isn't seen as a user edit.
            baselineCategoryId = selectedCategoryId
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Uploads the banner (if any) and persists the program — either creating
    /// it (POST /programs) or, in edit mode, sending a partial update
    /// (PATCH /programs/{id}). Returns `true` on success so the view can fire
    /// its completion callback and dismiss.
    func submit() async -> Bool {
        guard canSubmit else { return false }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // Upload each picked photo to R2 in order. A nil result means the
            // backend has no R2 bucket (local dev) — skip it so the gallery only
            // carries real URLs. The first surviving URL is the legacy banner.
            var galleryURLs: [String] = []
            for data in bannerImageData {
                if let url = try await UploadService.upload(data: data, kind: .program_banner) {
                    galleryURLs.append(url)
                }
            }

            // Resolve the picked map location to a backend row (find-or-create)
            // so the program links a real location_id. nil → create falls back
            // to the server default and edit keeps the existing location.
            var locationId: Int?
            if let picked = pickedLocation {
                let location: Location = try await httpClient.post(
                    "/locations", body: LocationCreateRequest(picked)
                )
                locationId = location.id
            }

            if let programId = editingProgramId {
                var request = ProgramUpdateRequest(
                    categoryId: selectedCategoryId,
                    programName: name,
                    description: description,
                    startDatetime: startDate,
                    endDatetime: endDate,
                    maxVolunteers: maxVolunteers,
                    commitmentFrequency: commitmentFrequency,
                    commitmentDuration: commitmentDuration
                )
                request.locationId = locationId
                // Only touch images when the host edited them. The new gallery is
                // the surviving saved images followed by freshly uploaded picks;
                // an empty result clears the gallery. Untouched → both fields nil
                // so the backend leaves the saved images alone.
                if imagesEdited {
                    let gallery = existingImageURLs + galleryURLs
                    request.bannerImageURLs = gallery
                    request.bannerImageURL = gallery.first
                }
                let _: Program = try await httpClient.patch("/programs/\(programId)", body: request)
            } else {
                var request = ProgramCreateRequest(
                    categoryId: selectedCategoryId,
                    programName: name,
                    description: description,
                    startDatetime: startDate,
                    endDatetime: endDate,
                    maxVolunteers: maxVolunteers,
                    commitmentFrequency: commitmentFrequency,
                    commitmentDuration: commitmentDuration,
                    bannerImageURL: galleryURLs.first,
                    bannerImageURLs: galleryURLs.isEmpty ? nil : galleryURLs
                )
                request.locationId = locationId
                let _: Program = try await httpClient.post("/programs", body: request)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
