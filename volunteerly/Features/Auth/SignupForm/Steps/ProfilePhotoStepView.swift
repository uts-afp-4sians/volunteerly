import SwiftUI
import PhotosUI

/// Step 2 of the signup form — "Add your photo" (Figma Profile Photo Screen,
/// node 600:311). Profile photo + Instagram handle, both optional.
struct ProfilePhotoStepView: View {
    @Bindable var vm: SignupFormViewModel

    @State private var profileItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Add your photo")
                .largeTitleStyle()

            photoPicker

            instagramField
        }
    }

    // MARK: Photo

    private var photoPicker: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $profileItem, matching: .images) {
                profileCircle
                    .frame(width: 100, height: 100)
            }
            .onChange(of: profileItem) { _, newItem in
                Task { vm.profileImageData = try? await newItem?.loadTransferable(type: Data.self) }
            }

            Text("Add profile photo")
                .font(.captionText)
                .foregroundStyle(Theme.textMeta)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var profileCircle: some View {
        if let data = vm.profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(Theme.surface)
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.placeholder)
            }
        }
    }

    // MARK: Instagram

    private var instagramField: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Instagram")
            ZStack(alignment: .leading) {
                if vm.instagram.isEmpty {
                    Text("@username")
                        .font(.bodyText)
                        .italic()
                        .foregroundStyle(Theme.placeholder)
                        .padding(.horizontal, 17)
                        .allowsHitTesting(false)
                }
                TextField("", text: $vm.instagram)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .formFieldSurface(height: 48)
            }
        }
    }
}
