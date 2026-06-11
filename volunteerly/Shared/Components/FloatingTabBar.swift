import SwiftUI

/// Floating tab bar that replaces the system tab bar: a frosted capsule holding
/// the three primary destinations (Programs, Bookmarks, Profile), with an
/// optional separate "+" circle for posting a program (shown on the Programs
/// list only).
struct FloatingTabBar: View {
    @Binding var selection: TabRouter.Tab
    var showsPostButton: Bool = false
    var onPostProgram: () -> Void = {}

    // Figma BOTTOM-TAB-BAR (526:784): 64×36 active pill, 24pt glyphs.
    private let pillWidth: CGFloat = 64
    private let pillHeight: CGFloat = 36

    var body: some View {
        ZStack {
            capsule

            if showsPostButton {
                HStack {
                    Spacer()
                    postButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var capsule: some View {
        HStack(spacing: 8) {
            tabButton(.programs, icon: "magnifyingglass", label: "Programs")
            tabButton(.bookmarks, icon: "heart.fill", label: "Saved")
            tabButton(.myPage, icon: "person.fill", label: "Profile")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
    }

    private var postButton: some View {
        Button(action: onPostProgram) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post a program")
    }

    private func tabButton(_ tab: TabRouter.Tab, icon name: String, label: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            Image(systemName: name)
                .font(.system(size: 22, weight: .regular))
                // Active glyph is Black/900 over the Brand/100 pill; idle is Black/500.
                .foregroundStyle(selected ? Color.textPrimary : Color.black500)
                .frame(width: pillWidth, height: pillHeight)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.brand100)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: TabRouter.Tab = .programs
    return ZStack {
        Color.brand.opacity(0.4).ignoresSafeArea()
        VStack {
            Spacer()
            FloatingTabBar(selection: $selection, showsPostButton: true)
        }
    }
}
