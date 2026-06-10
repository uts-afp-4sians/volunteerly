import SwiftUI

/// "Select Location" bottom sheet (Figma 226:685/226:687/329:903/329:909/
/// 329:915): grabber, centred title, search bar and map — two-way synced via
/// `LocationPickerMap` — and a Confirm pill that commits the pick.
///
/// Edits are staged on a local draft so swiping the sheet away cancels;
/// only Confirm writes back to the form.
struct LocationSelectionSheet: View {
    /// The structured pick the form submits (`POST /locations` → `location_id`).
    @Binding var picked: PickedLocation?
    /// Display string shown in the form's Location field.
    @Binding var regionName: String
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PickedLocation?

    var body: some View {
        VStack(spacing: 16) {
            // Custom blue drag handle matching the other PostProgram sheets.
            Capsule()
                .fill(Color.secondaryBlue)
                .frame(width: 56, height: 6)
                .padding(.top, 12)

            Text("Select Location")
                .font(.sectionHeader)
                .foregroundStyle(Theme.textPrimary)
                .padding(.bottom, 4)

            LocationPickerMap(picked: $draft, mapHeight: 249)
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            Button {
                picked = draft
                regionName = draft?.name ?? ""
                dismiss()
            } label: {
                Text("Confirm")
                    .font(.buttonLabel)
                    .foregroundStyle(Color.onBrand)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.brand, in: Capsule())
            }
            .disabled(draft == nil)
            .opacity(draft == nil ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.pageBackground)
        .onAppear { draft = picked }
    }
}

#Preview {
    @Previewable @State var picked: PickedLocation?
    @Previewable @State var name = ""
    return Color.clear.sheet(isPresented: .constant(true)) {
        LocationSelectionSheet(picked: $picked, regionName: $name)
            .presentationDetents([.height(520), .large])
    }
}
