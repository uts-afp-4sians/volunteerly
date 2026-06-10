import SwiftUI

struct LocationStepView: View {
    @Bindable var vm: SignupFormViewModel
    @State private var picked: PickedLocation?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where are you?")
                .largeTitleStyle()

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "City", required: true)

                // Shared search+map pair (Figma 329:903/329:909): panning the
                // map fills the field, picking a suggestion pins the map.
                LocationPickerMap(
                    picked: $picked,
                    mapHeight: 211,
                    initialName: vm.city.isEmpty ? nil : vm.city
                )
            }
        }
        .onChange(of: picked) { _, newValue in
            vm.city = newValue?.name ?? ""
            vm.pickedLocation = newValue
        }
    }
}
