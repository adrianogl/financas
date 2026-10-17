import SwiftUI

struct AppSidebar: View {
    @Environment(AppNavigation.self) private var navigation
    let counts: SidebarCounts

    var body: some View {
        List(selection: selection) {
            ForEach(AppTab.allCases, id: \.self) { section in
                AppSidebarRow(section: section, count: count(for: section))
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppSidebarHeader()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                AppSidebarFooter()
                Spacer(minLength: 8)
                SidebarToggleButton(isOpen: true) {
                    withAnimation { navigation.toggleSidebar() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar(.hidden, for: .navigationBar)
        .navigationSplitViewColumnWidth(LayoutConstants.sidebarWidth)
    }

    private var selection: Binding<AppTab?> {
        Binding(
            get: { navigation.section },
            set: { if let section = $0 { navigation.section = section } }
        )
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
