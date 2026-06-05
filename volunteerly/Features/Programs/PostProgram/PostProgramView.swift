import SwiftUI
import Combine
import MapKit
import CoreLocation

struct PostProgramView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Form State
    @State private var name: String = ""
    @State private var selectedCategoryId: Int = 1
    @State private var description: String = ""
    @State private var maxVolunteers: Int = 7 // Default to 7 like mockup
    
    // Details
    @State private var selectedRegion: String = ""
    @State private var startDate: Date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var selectedRepeat: String = "Every Week" // Matches "Every Week" from mockup
    
    // UI State
    @State private var showAlert = false
    @State private var activeSheet: SheetType? = nil
    
    enum SheetType: Identifiable {
        case location
        case startDate
        case endDate
        case repeatSelection

        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Full width progress bar matching the mockup (roughly 30% progress)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray6))
                    Rectangle()
                        .fill(Color.secondaryBlue)
                        .frame(width: geo.size.width * 0.3)
                }
            }
            .frame(height: 4)
            
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
                    
                    // Submit button
                    Button {
                        if !name.isEmpty && !description.isEmpty {
                            showAlert = true
                        }
                    } label: {
                        Text("Post Program")
                            .font(.bodyStrong)
                            .foregroundStyle(Color.onBrand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: 25))
                            .opacity(name.isEmpty || description.isEmpty ? 0.6 : 1.0)
                    }
                    .disabled(name.isEmpty || description.isEmpty)
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.pageBackground)
        }
        .background(Color.pageBackground)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Post Program")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .alert("Program Posted!", isPresented: $showAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your program '\(name)' has been successfully posted.")
        }
        .sheet(item: $activeSheet) { type in
            switch type {
            case .startDate:
                DateSelectionView(title: "Starts", date: $startDate, isAllDay: $isAllDay)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationDragIndicator(.visible)
            case .endDate:
                DateSelectionView(title: "Ends", date: $endDate, isAllDay: $isAllDay, minimumDate: startDate)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationDragIndicator(.visible)
            case .location:
                navSheet(detents: [.fraction(0.85), .large]) {
                    RegionSelectionView(selectedRegion: $selectedRegion)
                }
            case .repeatSelection:
                navSheet(detents: [.fraction(0.45)]) {
                    RepeatSelectionView(selectedRepeat: $selectedRepeat)
                }
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

    // MARK: - Subviews

    private func requiredLabel(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("*")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fieldError)
        }
    }

    private var categorySelectorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Category")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MockData.categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategoryId == category.id
                        ) {
                            selectedCategoryId = category.id
                        }
                    }
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Program name")
            
            TextField("Enter program name", text: $name)
                .textFieldStyle(.plain)
                .font(.bodyText)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Description")
            TextBox(
                text: $description,
                placeholder: "Describe the activities, requirements, and goal of this program...",
                height: 120
            )
        }
    }

    private var locationInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            requiredLabel("Location")
            
            Button {
                activeSheet = .location
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    Text(selectedRegion.isEmpty ? "Search" : selectedRegion)
                        .font(.bodyText)
                        .foregroundStyle(selectedRegion.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(Color(.systemGray6), in: Capsule())
            }
            .buttonStyle(.plain)
        }
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

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Date")
            
            VStack(spacing: 12) {
                // Starts row
                Button {
                    activeSheet = .startDate
                } label: {
                    HStack {
                        Text("Starts")
                            .font(.bodyText)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(formatDateOnly(startDate))
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                        Text(formatTimeOnly(startDate))
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                
                // Ends row
                Button {
                    activeSheet = .endDate
                } label: {
                    HStack {
                        Text("Ends")
                            .font(.bodyText)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(formatDateOnly(endDate))
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                        Text(formatTimeOnly(endDate))
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                
                // Repeat row
                Button {
                    activeSheet = .repeatSelection
                } label: {
                    HStack {
                        Text("Repeat")
                            .font(.bodyText)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(selectedRepeat)
                            .font(.bodyText)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var volunteersSliderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            requiredLabel("Volunteers Needed")
            
            VStack(spacing: 8) {
                // Value indicator above the slider
                Text("\(Int(maxVolunteers))")
                    .font(.bodyStrong)
                    .foregroundStyle(Color.secondaryBlue)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Slider(
                    value: Binding(
                        get: { Double(maxVolunteers) },
                        set: { maxVolunteers = Int(round($0)) }
                    ),
                    range: 1...10
                )
                
                HStack {
                    Text("1")
                        .font(.system(size: 12, weight: .semibold))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("10")
                        .font(.system(size: 12, weight: .semibold))
                        .italic()
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 12)
        }
    }
}

#Preview { PostProgramView() }
