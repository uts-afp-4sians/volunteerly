import SwiftUI

struct ProgramCard: View {
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: program.bannerImageURL ?? "")) { image in
                image.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().foregroundStyle(.quaternary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(program.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                BadgeView(status: program.status)
            }
            .padding([.horizontal, .bottom], 12)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

#Preview {
    ProgramCard(program: MockData.programs[0])
        .padding()
}
