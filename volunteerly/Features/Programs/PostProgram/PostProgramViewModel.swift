import Foundation
import Observation

@MainActor
@Observable
final class PostProgramViewModel {
    // MARK: - Form state

    var name: String = ""
    var selectedCategoryId: Int = 1
    var description: String = ""
    var maxVolunteers: Int = 7 // Default to 7 like mockup
    var commitmentFrequency: CommitmentFrequency?
    var commitmentDuration: CommitmentDuration?

    /// Banner image bytes, decoded by the picker in the view and uploaded to R2
    /// on submit. The preview `Image` stays view-side since it isn't submitted.
    var bannerImageData: Data?

    // MARK: - Details

    var selectedRegion: String = ""
    var startDate: Date
    var endDate: Date
    var selectedRepeat: String = "Never" // Default reoccurrence (Figma 329:1821)

    // MARK: - Network-backed state

    var categories: [ProgramCategory] = []
    var isSubmitting = false
    var errorMessage: String?

    /// Set when the form is editing an existing program. `nil` means create
    /// mode (POST), otherwise `submit()` issues a PATCH against this id.
    let editingProgramId: Int?

    var isEditing: Bool { editingProgramId != nil }

    var canSubmit: Bool {
        !name.isEmpty && !description.isEmpty && selectedCategoryId != 0 && !isSubmitting
    }

    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = LiveHTTPClient.shared) {
        self.httpClient = httpClient
        self.editingProgramId = nil
        let calendar = Calendar.current
        let now = Date()
        startDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        endDate = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: now)
            ?? now.addingTimeInterval(3600)
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
    }

    func loadCategories() async {
        do {
            let cats: [ProgramCategory] = try await httpClient.get("/categories")
            categories = cats
            if let first = cats.first,
               !cats.contains(where: { $0.id == selectedCategoryId }) {
                selectedCategoryId = first.id
            }
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
            var bannerURL: String? = nil
            if let data = bannerImageData {
                bannerURL = try await UploadService.upload(data: data, kind: .program_banner)
            }

            if let programId = editingProgramId {
                let request = ProgramUpdateRequest(
                    categoryId: selectedCategoryId,
                    programName: name,
                    description: description,
                    startDatetime: startDate,
                    endDatetime: endDate,
                    maxVolunteers: maxVolunteers,
                    commitmentFrequency: commitmentFrequency,
                    commitmentDuration: commitmentDuration,
                    bannerImageURL: bannerURL  // nil → backend keeps existing
                )
                let _: Program = try await httpClient.patch("/programs/\(programId)", body: request)
            } else {
                let request = ProgramCreateRequest(
                    categoryId: selectedCategoryId,
                    programName: name,
                    description: description,
                    startDatetime: startDate,
                    endDatetime: endDate,
                    maxVolunteers: maxVolunteers,
                    commitmentFrequency: commitmentFrequency,
                    commitmentDuration: commitmentDuration,
                    bannerImageURL: bannerURL
                )
                let _: Program = try await httpClient.post("/programs", body: request)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
