import SwiftUI

struct MainTabView: View {
    @Environment(IncomeStore.self) private var incomeStore
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
    }
}
