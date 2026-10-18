import SwiftUI

struct MainTabView: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(LockManager.self) private var lockManager
    @Environment(ReminderRouter.self) private var router
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var windowSize = CGSize.zero
    @State private var accountMenu = AccountMenuState()

    var body: some View {
        let mode = LayoutMode.make(isRegular: sizeClass == .regular, size: windowSize)
        let counts = sidebarCounts

        ZStack {
            if windowSize == .zero {
                Color.clear
            } else if mode == .compact {
                compactTabs(overdueCount: counts.overdue)
            } else {
                SidebarNavigation(mode: mode, counts: counts)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size, initial: true) { windowSize = proxy.size }
            }
            .ignoresSafeArea()
        }
        .accountPresentations(accountMenu)
        .onChange(of: mode, initial: true) { navigation.enter(mode) }
        .onAppear(perform: applyPendingRoute)
        .onChange(of: router.pendingRoute, applyPendingRoute)
        .onChange(of: lockManager.isUnlocked, applyPendingRoute)
    }

    private func compactTabs(overdueCount: Int) -> some View {
        @Bindable var navigation = navigation
        return TabView(selection: $navigation.section) {
            ForEach(AppTab.allCases, id: \.self) { section in
                Tab(value: section) {
                    AppSectionView(section: section)
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .labelStyle(.iconOnly)
                }
                .badge(section == .overdue ? overdueCount : 0)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var sidebarCounts: SidebarCounts {
        let month = incomeStore.selectedMonth
        let today = incomeStore.today
        return SidebarCounts(
            incomes: incomeStore.occurrences(in: month),
            expenses: expenseStore.occurrences(in: month, today: today),
            overdue: incomeStore.overdueOccurrences.count + expenseStore.overduePayables(today: today).count
        )
    }

    private func applyPendingRoute() {
        switch router.take(isUnlocked: lockManager.isUnlocked) {
        case .overdue:
            navigation.section = .overdue
        case .incomes:
            incomeStore.showCurrentMonth()
            navigation.section = .incomes
        case .expenses:
            incomeStore.showCurrentMonth()
            navigation.section = .expenses
        case nil:
            break
        }
    }
}
