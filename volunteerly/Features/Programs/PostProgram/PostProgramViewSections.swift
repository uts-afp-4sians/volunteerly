import SwiftUI
import PhotosUI

// MARK: - Jiggle effect

/// iOS home-screen "jiggle": a continuous, gentle back-and-forth tilt used to
/// signal that an item is in edit/delete mode. Each item is phase-shifted by
/// its index so the row doesn't wobble in lockstep, and the whole effect is
/// suppressed when Reduce Motion is on (HIG).
private struct JiggleEffect: ViewModifier {
    let isActive: Bool
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wobble = false

    private let angle: Double = 1.8

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .animation(animation, value: wobble)
            .animation(animation, value: isActive)
            .onChange(of: isActive) { _, active in wobble = active }
            .onAppear { wobble = isActive }
    }

    private var rotation: Double {
        guard isActive, !reduceMotion else { return 0 }
        return wobble ? angle : -angle
    }

    private var animation: Animation? {
        guard isActive, !reduceMotion else { return .easeOut(duration: 0.2) }
        return .easeInOut(duration: 0.13)
            .repeatForever(autoreverses: true)
            .delay(Double(index % 3) * 0.05)
    }
}

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

    // MARK: Add images

    /// "Add images" (Figma 190:639): a header with an "Up to three photos" hint,
    /// a row of three thumbnail slots, and a large picker that fills the next
    /// empty slot. Long-pressing a filled thumbnail enters an iOS home-screen
    /// style edit mode — the row jiggles and a delete badge removes that photo.
    var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                optionalLabel("Add images")
                Spacer()
                Text("Up to three photos")
                    .font(.buttonLabel)
                    .foregroundStyle(Theme.textSecondary)
            }

            // Only show the thumbnail row once at least one photo is picked —
            // an empty row of grey placeholders reads as a loading skeleton.
            if !photoImages.isEmpty {
                HStack(spacing: 12) {
                    ForEach(0..<maxPhotos, id: \.self) { index in
                        photoThumbnail(at: index)
                    }
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
    /// placeholder. Long-pressing a filled slot enters edit mode (jiggle +
    /// delete badge); tapping the badge removes that photo.
    @ViewBuilder
    private func photoThumbnail(at index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if index < photoImages.count {
            // Fix the slot to a 1:1 square first (identical sizing to the empty
            // placeholder below), then fill it with the photo and crop the
            // overflow — so portrait and landscape picks render the same size.
            shape
                .fill(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    photoImages[index]
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(shape)
                .modifier(JiggleEffect(isActive: photosEditing, index: index))
                .overlay(alignment: .topTrailing) {
                    if photosEditing {
                        photoDeleteBadge(at: index)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onLongPressGesture(minimumDuration: 0.35) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        photosEditing = true
                    }
                }
        } else {
            shape
                .fill(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    /// Circular "✕" delete badge that hangs over the thumbnail's top-right
    /// corner. The visible disc is small, but transparent padding inflates the
    /// hit area to ~44pt so it stays comfortably thumb-tappable.
    private func photoDeleteBadge(at index: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.2)) {
                removePhoto(at: index)
                if photoImages.isEmpty { photosEditing = false }
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .padding(10)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 14, y: -14)
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
