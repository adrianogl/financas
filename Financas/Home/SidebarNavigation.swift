import SwiftUI

struct SidebarNavigation: View {
    @Environment(AppNavigation.self) private var navigation
    let mode: LayoutMode
    let counts: SidebarCounts

    var body: some View {
        @Bindable var navigation = navigation
        let isOpen = navigation.showsSidebar(in: mode)

        HStack(spacing: 0) {
            if isOpen {
                AppSidebar(counts: counts)
                    .frame(width: LayoutConstants.sidebarWidth)
                    .padding(NavigationConstants.sidebarInset)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            VStack(spacing: 0) {
                if !isOpen {
                    SectionTabBar(selection: $navigation.section, overdueCount: counts.overdue)
                        .padding(.top, NavigationConstants.tabBarTopPadding)
                }
                SectionStack(selection: navigation.section)
            }
        }
        .background(AppBackground())
        .overlay(alignment: .bottomLeading) {
            if !isOpen {
                SidebarToggleButton(isOpen: false) {
                    withAnimation { navigation.setSidebar(open: true, in: mode) }
                }
                .padding(NavigationConstants.toggleMargin)
            }
        }
    }
}
