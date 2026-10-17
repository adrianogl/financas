import SwiftUI

struct SidebarNavigation: View {
    @Environment(AppNavigation.self) private var navigation
    let mode: LayoutMode
    let counts: SidebarCounts

    var body: some View {
        @Bindable var navigation = navigation
        let isOpen = navigation.showsSidebar(in: mode)

        VStack(spacing: 0) {
            if !isOpen {
                SectionTabBar(selection: $navigation.section, overdueCount: counts.overdue)
                    .padding(.top, NavigationConstants.tabBarTopPadding)
            }
            NavigationSplitView(columnVisibility: visibility) {
                AppSidebar(counts: counts)
            } detail: {
                AppSectionView(section: navigation.section)
            }
            .toolbar(removing: .sidebarToggle)
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

    private var visibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { navigation.showsSidebar(in: mode) ? .all : .detailOnly },
            set: { navigation.setSidebar(open: $0 != .detailOnly, in: mode) }
        )
    }
}
