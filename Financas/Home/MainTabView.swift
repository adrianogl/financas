import SwiftUI

struct MainTabView: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(LockManager.self) private var lockManager
    @Environment(ReminderRouter.self) private var router
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.home) {
                HomeView(selectedTab: $selectedTab)
            } label: {
                Label("Início", systemImage: "house")
                    .labelStyle(.iconOnly)
            }
            Tab(value: AppTab.incomes) {
                IncomesView()
            } label: {
                Label("Receitas", systemImage: "arrow.down.circle")
                    .labelStyle(.iconOnly)
            }
            Tab(value: AppTab.expenses) {
                ExpensesView()
            } label: {
                Label("Despesas", systemImage: "arrow.up.circle")
                    .labelStyle(.iconOnly)
            }
            Tab(value: AppTab.overdue) {
                OverdueView()
            } label: {
                Label("Atrasadas", systemImage: "exclamationmark.circle")
                    .labelStyle(.iconOnly)
            }
            .badge(overdueCount)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear(perform: applyPendingRoute)
        .onChange(of: router.pendingRoute, applyPendingRoute)
        .onChange(of: lockManager.isUnlocked, applyPendingRoute)
    }

    private var overdueCount: Int {
        incomeStore.overdueOccurrences.count + expenseStore.overdueOccurrences(today: incomeStore.today).count
    }

    private func applyPendingRoute() {
        switch router.take(isUnlocked: lockManager.isUnlocked) {
        case .overdue:
            selectedTab = .overdue
        case .incomes:
            incomeStore.showCurrentMonth()
            selectedTab = .incomes
        case .expenses:
            incomeStore.showCurrentMonth()
            selectedTab = .expenses
        case nil:
            break
        }
    }
}
