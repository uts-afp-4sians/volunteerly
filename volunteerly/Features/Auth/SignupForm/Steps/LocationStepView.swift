import SwiftUI
import MapKit

struct LocationStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where are you?")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)

            if let locationError = vm.locationError {
                Text(locationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 3) {
                    Text("City")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("*").requiredFieldStyle()
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    TextField("Search", text: $vm.city)
                        .submitLabel(.search)
                        .onSubmit { vm.geocodeCity() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 0) {
                Map(position: $vm.mapCameraPosition)
                    .frame(height: 280)
                    .disabled(true)

                Button {
                    vm.geocodeCity()
                } label: {
                    HStack(spacing: 8) {
                        if vm.isGeocodingCity {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .controlSize(.small)
                        }
                        Text(vm.isGeocodingCity ? "Searching…" : "Select location")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(vm.city.isEmpty ? Theme.border : Theme.forest)
                }
                .disabled(vm.city.isEmpty || vm.isGeocodingCity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .task {
            vm.useCurrentLocation()
        }
    }
}
