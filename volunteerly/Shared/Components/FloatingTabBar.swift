import SwiftUI

/// Floating capsule that replaces the system tab bar. Three icons (Programs,
/// My Programs, Profile) sit inside a white pill with a soft shadow.
struct FloatingTabBar: View {
    @Binding var selection: TabRouter.Tab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.programs, icon: "magnifyingglass", label: "Programs")
            tabButton(.bookmarks, icon: "rectangle.stack.fill", label: "My Programs")
            tabButton(.myPage, icon: "person.crop.circle.fill", label: "Profile")
        }
        .frame(width: 200, height: 52)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
    }

    private func tabButton(_ tab: TabRouter.Tab, icon: String, label: String) -> some View {
        Button {
            selection = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(selection == tab ? Color.brand : Color.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    @Previewable @State var selection: TabRouter.Tab = .programs
    return FloatingTabBar(selection: $selection)
        .padding(40)
        .background(Color.pageBackground)
}
