import SwiftUI

struct AppSidebarRow: View {
    let section: AppTab
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .frame(width: NavigationConstants.sidebarIconWidth)
                Text(section.title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .fontWeight(section == .overdue ? .semibold : .regular)
                        .foregroundStyle(section == .overdue ? Theme.warning : .secondary)
                }
            }
            .foregroundStyle(isSelected ? Theme.accent : .primary)
            .padding(.horizontal, NavigationConstants.sidebarRowHorizontalPadding)
            .padding(.vertical, NavigationConstants.sidebarRowVerticalPadding)
            .background(
                isSelected ? Theme.accent.opacity(NavigationConstants.selectedTabOpacity) : .clear,
                in: .rect(cornerRadius: NavigationConstants.sidebarRowCornerRadius)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
