import SwiftUI

struct AppSidebar: View {
    @Environment(AppNavigation.self) private var navigation
    let counts: SidebarCounts

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            AppSidebarHeader()
            ForEach(AppTab.allCases, id: \.self) { section in
                AppSidebarRow(
                    section: section,
                    count: count(for: section),
                    isSelected: navigation.section == section
                ) {
                    navigation.section = section
                }
            }
            Spacer(minLength: 0)
            HStack {
                AppSidebarFooter()
                Spacer(minLength: 8)
                SidebarToggleButton(isOpen: true) {
                    withAnimation { navigation.toggleSidebar() }
                }
            }
        }
        .padding(NavigationConstants.sidebarPadding)
        .frame(maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: NavigationConstants.sidebarCornerRadius))
    }

    private func count(for section: AppTab) -> Int {
        switch section {
        case .home:
            0
        case .incomes:
            counts.incomes
        case .expenses:
            counts.expenses
        case .overdue:
            counts.overdue
        }
    }
}
