import SwiftUI

/// Floating tab bar that replaces the system tab bar: a frosted capsule holding
/// the three primary destinations (Programs, Bookmarks, Profile), with an
/// optional separate "+" circle for posting a program (shown on the Programs
/// list only).
struct FloatingTabBar: View {
    @Binding var selection: TabRouter.Tab
    var showsPostButton: Bool = false
    var onPostProgram: () -> Void = {}

    private let itemSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 12) {
            capsule
            if showsPostButton {
                postButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var capsule: some View {
        HStack(spacing: 4) {
            tabButton(.programs, icon: "magnifyingglass", label: "Programs")
            tabButton(.bookmarks, icon: "bookmark", label: "Bookmarks")
            tabButton(.myPage, icon: "person.crop.circle", label: "My page")
        }
        .padding(.horizontal, 10)
        .frame(height: itemSize)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var postButton: some View {
        Button(action: onPostProgram) {
            icon("plus", selected: false)
                .frame(width: itemSize, height: itemSize)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post a program")
    }

    private func tabButton(_ tab: TabRouter.Tab, icon name: String, label: String) -> some View {
        Button {
            selection = tab
        } label: {
            icon(name, selected: selection == tab)
                .frame(width: itemSize, height: itemSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private func icon(_ name: String, selected: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(selected ? Color.brand : Color.textPrimary)
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
