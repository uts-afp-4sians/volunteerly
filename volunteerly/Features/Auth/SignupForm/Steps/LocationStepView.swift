import SwiftUI
import MapKit

struct LocationStepView: View {
    @Bindable var vm: SignupFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Where are you?")
                .largeTitleStyle()

            if let locationError = vm.locationError {
                Text(locationError)
                    .font(.subheadText)
                    .foregroundStyle(Color.fieldError)
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "City", required: true)

                // Figma SEARCH-BAR — Black/50 fill, 40pt-tall pill.
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.iconPrimary)
                    if vm.isGeocodingCity {
                        ProgressView().controlSize(.small).tint(Theme.placeholder)
                    }
                    TextField("Search", text: $vm.city)
                        .font(.bodyText)
                        .submitLabel(.search)
                        .onSubmit { vm.geocodeCity() }
                }
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(Theme.surface)
                .clipShape(Capsule())
            }

            // Figma map card — 211pt tall, 30pt radius.
            Map(position: $vm.mapCameraPosition)
                .onMapCameraChange(frequency: .onEnd) { context in
                    vm.reverseGeocode(coordinate: context.region.center)
                }
                .overlay(alignment: .center) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.sectionTitle)
                        .foregroundStyle(Theme.brandPrimary)
                        .background(Circle().fill(.white).padding(4))
                        .offset(y: -15)
                }
                .frame(height: 211)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .task {
            vm.useCurrentLocation()
        }
    }
}
