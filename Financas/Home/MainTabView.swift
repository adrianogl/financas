import SwiftUI

struct MainTabView: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(LockManager.self) private var lockManager
    @Environment(ReminderRouter.self) private var router
    @State private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Início", systemImage: "house", value: AppTab.home) {
                HomeView(selectedTab: $selectedTab)
            }
            Tab("Receitas", systemImage: "arrow.down.circle", value: AppTab.incomes) {
                IncomesView()
            }
            Tab("Atrasadas", systemImage: "exclamationmark.circle", value: AppTab.overdue) {
                OverdueView()
            }
            .badge(incomeStore.overdueOccurrences.count)
        }
        .onAppear(perform: applyPendingRoute)
        .onChange(of: router.pendingRoute, applyPendingRoute)
        .onChange(of: lockManager.isUnlocked, applyPendingRoute)
    }

    private func applyPendingRoute() {
        switch router.take(isUnlocked: lockManager.isUnlocked) {
        case .overdue:
            selectedTab = .overdue
        case .incomes:
            incomeStore.showCurrentMonth()
            selectedTab = .incomes
        case nil:
            break
        }
    }
}
