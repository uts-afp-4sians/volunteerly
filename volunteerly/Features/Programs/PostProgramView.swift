import SwiftUI
import Combine

struct PostProgramView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Form State
    @State private var name: String = ""
    @State private var selectedCategoryId: Int = 1
    @State private var description: String = ""
    @State private var bannerImageURL: String = "https://images.unsplash.com/photo-1544027993-37dbfe43562a"
    @State private var maxVolunteers: Int = 10
    
    // Details
    @State private var selectedRegion: String = "New South Wales (NSW)"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600 * 3)
    @State private var isAllDay: Bool = false
    @State private var selectedRepeat: String = "None"
    
    // UI State
    @State private var showAlert = false
    
    // Sheet State
    @State private var activeSheet: SheetType? = nil
    
    enum SheetType: Identifiable {
        case location
        case date
        case repeatSelection
        
        var id: Self { self }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: startDate)
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: startDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    bannerSelector
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Program Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Program Name *")
                                .font(.bodyStrong)
                                .foregroundStyle(Theme.textPrimary)
                            
                            HStack {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Theme.textSecondary)
                                TextField("Enter program name", text: $name)
                                    .textFieldStyle(.plain)
                                    .font(.bodyText)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Category selection
                        categorySelectorRow
                        
                        // Description
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description *")
                                .font(.bodyStrong)
                                .foregroundStyle(Theme.textPrimary)
                            TextBox(
                                text: $description,
                                placeholder: "Describe the activities, requirements, and goal of this program...",
                                height: 120
                            )
                        }
                        
                        // Stepper for max volunteers
                        volunteersStepper
                        
                        // Detail Rows (opening bottom sheets)
                        VStack(spacing: 12) {
                            Button {
                                activeSheet = .location
                            } label: {
                                DetailRow(title: "Location", value: selectedRegion, icon: "mappin.and.ellipse")
                            }
                            .buttonStyle(.plain)

                            Button {
                                activeSheet = .date
                            } label: {
                                DetailRow(title: "Date & Time", value: formattedDate, icon: "calendar")
                            }
                            .buttonStyle(.plain)

                            Button {
                                activeSheet = .repeatSelection
                            } label: {
                                DetailRow(title: "Repeat", value: selectedRepeat, icon: "repeat")
                            }
                            .buttonStyle(.plain)
                        }
                        
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
                }
                .padding(.vertical, 16)
            }
            .background(Color.pageBackground)
            .navigationTitle("Post a Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
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
                NavigationStack {
                    Group {
                        switch type {
                        case .location:
                            RegionSelectionView(selectedRegion: $selectedRegion)
                        case .date:
                            DateSelectionView(startDate: $startDate, endDate: $endDate, isAllDay: $isAllDay)
                        case .repeatSelection:
                            RepeatSelectionView(selectedRepeat: $selectedRepeat)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                activeSheet = nil
                            }
                        }
                    }
                }
                .presentationDetents(detents(for: type))
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func detents(for type: SheetType) -> Set<PresentationDetent> {
        switch type {
        case .location:
            return [.fraction(0.85), .large]
        case .date:
            return [.fraction(0.65), .large]
        case .repeatSelection:
            return [.fraction(0.45)]
        }
    }

    // MARK: - Subviews

    private var bannerSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Banner Image")
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 20)
            
            Button {
                let mockImages = [
                    "https://images.unsplash.com/photo-1544027993-37dbfe43562a",
                    "https://images.unsplash.com/photo-1593113598332-cd288d649433",
                    "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c"
                ]
                if let index = mockImages.firstIndex(of: bannerImageURL) {
                    bannerImageURL = mockImages[(index + 1) % mockImages.count]
                } else {
                    bannerImageURL = mockImages[0]
                }
            } label: {
                ZStack {
                    AsyncImage(url: URL(string: bannerImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.3))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                        Text("Tap to Change Photo")
                            .font(.buttonLabel)
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 140)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var categorySelectorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Category *")
                .font(.bodyStrong)
                .foregroundStyle(Theme.textPrimary)
            
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

    private var volunteersStepper: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Max Volunteers *")
                    .font(.bodyStrong)
                    .foregroundStyle(Theme.textPrimary)
                Text("Ensure enough capacity")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    if maxVolunteers > 1 { maxVolunteers -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(maxVolunteers > 1 ? Color.brand : .secondary)
                }
                .buttonStyle(.plain)
                
                Text("\(maxVolunteers)")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 36, alignment: .center)
                
                Button {
                    maxVolunteers += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.brand)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.brand)
                .frame(width: 24)
            
            Text(title)
                .font(.bodyText)
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.bodyText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Sub-screens

struct RegionSelectionView: View {
    @Binding var selectedRegion: String
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    @StateObject private var locationManager = LocationManager()

    let regions = [
        "New South Wales (NSW)",
        "Victoria (VIC)",
        "Queensland (QLD)",
        "Western Australia (WA)",
        "South Australia (SA)",
        "Tasmania (TAS)",
        "Australian Capital Territory (ACT)",
        "Northern Territory (NT)"
    ]

    var filteredRegions: [String] {
        if searchText.isEmpty {
            return regions
        } else {
            return regions.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Subtle locating progress bar
            if locationManager.isLocating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Auto-detecting current location...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.brand)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.brand.opacity(0.08))
            } else if let error = locationManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fieldError)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fieldError)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.fieldError.opacity(0.08))
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search regions", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color(.systemGray6), in: Capsule())
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(filteredRegions, id: \.self) { region in
                        Button {
                            selectedRegion = region
                            dismiss()
                        } label: {
                            HStack {
                                Text(region)
                                    .font(.bodyText)
                                    .foregroundStyle(selectedRegion == region ? Color.brand : .primary)
                                Spacer()
                                if selectedRegion == region {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.brand)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedRegion == region ? Color.brand : Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.pageBackground)
        .navigationTitle("Select Region")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestPermissionAndLocation()
        }
        .onChange(of: locationManager.currentLocationName) { _, newValue in
            if let detected = newValue {
                selectedRegion = detected
                dismiss()
            }
        }
    }
}

struct DateSelectionView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    @Environment(\.dismiss) var dismiss

    var durationText: String {
        if isAllDay {
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return days <= 0 ? "1 day" : "\(days + 1) days"
        } else {
            let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
            if minutes < 60 {
                return "\(minutes) minutes"
            } else {
                let hours = Double(minutes) / 60.0
                return String(format: "%.1f hours", hours)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.bodyStrong)
                        .foregroundStyle(Theme.textPrimary)
                    Text(durationText)
                        .font(.pageTitle)
                        .foregroundStyle(Color.brand)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                VStack(spacing: 20) {
                    HStack {
                        Text("All-Day Event")
                            .font(.bodyText)
                        Spacer()
                        Toggle(isOn: $isAllDay)
                    }
                    
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Starts")
                            .font(.buttonLabel)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: $startDate,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.brand)
                    }
                    
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ends")
                            .font(.buttonLabel)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .tint(Color.brand)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.bodyStrong)
                        .foregroundStyle(Color.onBrand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Select Date & Time")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RepeatSelectionView: View {
    @Binding var selectedRepeat: String
    @Environment(\.dismiss) var dismiss
    
    let options = ["None", "Daily", "Weekly", "Bi-weekly", "Monthly"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    RadioButton(
                        title: option,
                        isSelected: Binding(
                            get: { selectedRepeat == option },
                            set: { isSelected in
                                if isSelected {
                                    selectedRepeat = option
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        dismiss()
                                    }
                                }
                            }
                        )
                    )
                }
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Location Manager

import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocationName: String? = nil
    @Published var isLocating = false
    @Published var errorMessage: String? = nil
    
    override init() {
        super.init()
        manager.delegate = self
        self.authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermissionAndLocation() {
        isLocating = true
        errorMessage = nil
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access denied. Enable in Settings."
            isLocating = false
        @unknown default:
            isLocating = false
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLocating = false
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                self?.isLocating = false
                if let error = error {
                    self?.errorMessage = "Failed to detect: \(error.localizedDescription)"
                    return
                }
                
                if let placemark = placemarks?.first {
                    let state = placemark.administrativeArea ?? ""
                    let locality = placemark.locality ?? placemark.subLocality ?? ""
                    
                    if !locality.isEmpty && !state.isEmpty {
                        self?.currentLocationName = "\(locality), \(state)"
                    } else if !state.isEmpty {
                        self?.currentLocationName = state
                    } else if let country = placemark.country {
                        self?.currentLocationName = country
                    } else {
                        self?.errorMessage = "Could not resolve location."
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = "Error: \(error.localizedDescription)"
    }
}

#Preview { PostProgramView() }
