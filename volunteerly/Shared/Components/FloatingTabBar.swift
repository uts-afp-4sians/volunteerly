import SwiftUI

/// Floating tab bar that replaces the system tab bar: a frosted capsule
/// holding the three primary destinations (Programs, Bookmarks, Settings),
/// horizontally centred on screen. When `showsPostButton` is true a separate
/// "+" circle floats to the trailing edge, slightly above the capsule.
struct FloatingTabBar: View {
    @Binding var selection: TabRouter.Tab
    var showsPostButton: Bool = false
    var onPostProgram: () -> Void = {}

    private let itemSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            capsule
            Spacer()
        }
        .overlay(alignment: .trailing) {
            if showsPostButton {
                postButton
                    .padding(.trailing, 12)
                    .offset(y: -12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var capsule: some View {
        HStack(spacing: 4) {
            tabButton(.programs, icon: "magnifyingglass", label: "Programs")
            tabButton(.bookmarks, icon: "bookmark", label: "Bookmarks")
            tabButton(.settings, icon: "gearshape", label: "Settings")
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
