import SwiftUI

struct SidebarToggleButton: View {
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: NavigationConstants.toggleSize, height: NavigationConstants.toggleSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isOpen ? "Esconder barra lateral" : "Mostrar barra lateral")
    }
}
