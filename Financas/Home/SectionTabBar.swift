import SwiftUI

struct SectionTabBar: View {
    @Binding var selection: AppTab
    let overdueCount: Int

    var body: some View {
        HStack(spacing: NavigationConstants.tabBarSpacing) {
            ForEach(AppTab.allCases, id: \.self) { section in
                item(section)
            }
        }
        .padding(NavigationConstants.tabBarPadding)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func item(_ section: AppTab) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            Image(systemName: section.systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? Theme.accent : .primary)
                .frame(width: NavigationConstants.tabBarItemWidth, height: NavigationConstants.tabBarItemHeight)
                .background(isSelected ? Theme.accent.opacity(NavigationConstants.selectedTabOpacity) : .clear, in: .capsule)
                .overlay(alignment: .topTrailing) {
                    if section == .overdue && overdueCount > 0 {
                        Text("\(overdueCount)")
                            .font(.caption2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, NavigationConstants.badgePadding)
                            .frame(minWidth: NavigationConstants.badgeMinSize, minHeight: NavigationConstants.badgeMinSize)
                            .background(.red, in: .capsule)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityValue(section == .overdue && overdueCount > 0 ? "\(overdueCount)" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
