import SwiftUI
import PhotosUI

// MARK: - Form sections
//
// The visual building blocks of `PostProgramView`, split out to keep the main
// file focused on layout, sheets, and picker plumbing. Every section reads form
// state from `viewModel` and routes sheet taps through `presentSheet(_:)`.

extension PostProgramView {

    // MARK: Labels

    func requiredLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("*")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fieldError)
        }
    }

    func optionalLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
    }

    // MARK: Category

    var categorySelectorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Category")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategoryId == category.id
                        ) {
                            viewModel.selectedCategoryId = category.id
                        }
                    }
                }
            }
        }
    }

    // MARK: Name & description

    var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Program name")

            TextField("Enter program name", text: $viewModel.name)
                .textFieldStyle(.plain)
                .font(.bodyText)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Description")
            TextBox(
                text: $viewModel.description,
                placeholder: "Describe the activities, requirements, and goal of this program...",
                height: 120
            )
        }
    }

    // MARK: Location

    var locationInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Location")

            Button {
                presentSheet(.location)
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    Text(viewModel.selectedRegion.isEmpty ? "Search" : viewModel.selectedRegion)
                        .font(.bodyText)
                        .foregroundStyle(viewModel.selectedRegion.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(Color(.systemGray6), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Date

    var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Date")

            // Figma "Section - Repeated Event Toggle" (node 224:293): a 12pt-radius
            // card whose rows are separated by edge-to-edge dividers. Each row pads
            // 16h / 12v; date & time read as filled chips, Repeat as a value + chevron.
            VStack(spacing: 0) {
                dateTimeRow(
                    label: "Starts",
                    date: viewModel.startDate,
                    onDate: { presentSheet(.startDate) },
                    onTime: { presentSheet(.startTime) }
                )

                Divider()

                dateTimeRow(
                    label: "Ends",
                    date: viewModel.endDate,
                    onDate: { presentSheet(.endDate) },
                    onTime: { presentSheet(.endTime) }
                )

                Divider()

                repeatRow
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// A "Starts"/"Ends" row: label on the left, independently-tappable date and
    /// time chips on the right. The date chip opens the calendar sheet, the time
    /// chip opens the time-wheel sheet.
    private func dateTimeRow(
        label: String,
        date: Date,
        onDate: @escaping () -> Void,
        onTime: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Button(action: onDate) { dateChip(formatDateOnly(date)) }
                    .buttonStyle(.plain)
                Button(action: onTime) { dateChip(formatTimeOnly(date)) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// A filled grey chip carrying a date or time string (Figma "Button", r8).
    private func dateChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var repeatRow: some View {
        Button {
            presentSheet(.repeatSelection)
        } label: {
            HStack(spacing: 0) {
                Text("Repeat")
                    .font(.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    Text(viewModel.selectedRepeat)
                        .font(.buttonLabel)
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: Volunteers slider

    var volunteersSliderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Volunteers Needed")

            VStack(spacing: 8) {
                // Endpoint labels (1, 10) plus the current value, all on one row
                // above the track. The current value tracks the knob centre using
                // the same geometry as `Slider` (knobWidth = 49).
                GeometryReader { geo in
                    let knobWidth: CGFloat = 49
                    let lower = 1.0, upper = 10.0
                    let value = Double(viewModel.maxVolunteers)
                    let usable = max(geo.size.width - knobWidth, 1)
                    let fraction = min(max((value - lower) / (upper - lower), 0), 1)
                    let knobCenterX = fraction * usable + knobWidth / 2

                    ZStack(alignment: .topLeading) {
                        sliderNumber("1")
                            .position(x: knobWidth / 2, y: geo.size.height / 2)
                        sliderNumber("10")
                            .position(x: geo.size.width - knobWidth / 2, y: geo.size.height / 2)
                        sliderNumber("\(viewModel.maxVolunteers)")
                            .position(x: knobCenterX, y: geo.size.height / 2)
                    }
                }
                .frame(height: 20)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.maxVolunteers) },
                        set: { viewModel.maxVolunteers = Int(round($0)) }
                    ),
                    range: 1...10
                )
            }
            .padding(.vertical, 12)
        }
    }

    private func sliderNumber(_ text: String) -> some View {
        Text(text)
            .font(.labelItalic)
            .foregroundStyle(Color.textPrimary)
            .fixedSize()
    }

    // MARK: Banner image

    /// Single banner image picker — uploads to R2 on submit.
    var bannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            optionalLabel("Banner image")

            PhotosPicker(selection: $bannerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                    if let preview = bannerPreview {
                        preview
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.textPrimary.opacity(0.5))
                            Text("Add banner")
                                .font(.buttonLabel)
                                .foregroundStyle(Color.textPrimary.opacity(0.5))
                        }
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .onChange(of: bannerItem) { _, item in
                Task { await handleBannerChange(item) }
            }
        }
    }

    // MARK: Add images

    /// "Add images" (Figma 190:639): a header with an "Up to three photos" hint,
    /// a row of three thumbnail slots, and a large picker that fills the next
    /// empty slot. Tapping a filled thumbnail removes that photo.
    var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                optionalLabel("Add images")
                Spacer()
                Text("Up to three photos")
                    .font(.buttonLabel)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 12) {
                ForEach(0..<maxPhotos, id: \.self) { index in
                    photoThumbnail(at: index)
                }
            }

            PhotosPicker(
                selection: $photoItems,
                maxSelectionCount: maxPhotos,
                matching: .images
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
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
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .onChange(of: photoItems) { _, items in
            Task { await loadPhotos(items) }
        }
    }

    /// One of the three thumbnail slots: the selected photo, or an empty
    /// placeholder. Tapping a filled slot removes that photo.
    @ViewBuilder
    private func photoThumbnail(at index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if index < photoImages.count {
            Button {
                removePhoto(at: index)
            } label: {
                photoImages[index]
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(shape)
            }
            .buttonStyle(.plain)
        } else {
            shape
                .fill(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    // MARK: Commitment

    var commitmentFrequencyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            optionalLabel("Commitment frequency")
            FlowLayout(spacing: 12) {
                ForEach(CommitmentFrequency.allCases) { frequency in
                    FilterChip(
                        title: frequency.label,
                        isSelected: viewModel.commitmentFrequency == frequency
                    ) {
                        viewModel.commitmentFrequency = (viewModel.commitmentFrequency == frequency) ? nil : frequency
                    }
                }
            }
        }
    }

    var commitmentDurationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            optionalLabel("Commitment duration(month)")
            FlowLayout(spacing: 12) {
                ForEach(CommitmentDuration.allCases) { duration in
                    FilterChip(
                        title: duration.label,
                        isSelected: viewModel.commitmentDuration == duration
                    ) {
                        viewModel.commitmentDuration = (viewModel.commitmentDuration == duration) ? nil : duration
                    }
                }
            }
        }
    }
}
