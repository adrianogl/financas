import SwiftUI

struct HomeView: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        NavigationStack {
            Group {
                if navigation.mode == .compact {
                    compact
                } else {
                    HomeWideView()
                        .toolbar(navigation.isSidebarVisible ? .hidden : .automatic, for: .navigationBar)
                }
            }
            .background(AppBackground())
            .toolbar {
                if !navigation.isSidebarVisible {
                    ToolbarItem(placement: .topBarTrailing) {
                        AccountMenu {
                            AccountAvatar()
                                .accessibilityLabel("Conta")
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
        }
    }

    private var compact: some View {
        @Bindable var incomeStore = incomeStore
        let month = incomeStore.selectedMonth
        let summary = HomeMonthSummary.make(month: month, snapshot: incomeStore.snapshot, expenses: expenseStore.snapshot, today: incomeStore.today)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HomeHeader()
                MonthPicker(month: $incomeStore.selectedMonth)
                BalanceChartCard(summary: summary, chartHeight: 96, showsDayScale: false)
                MonthBalanceCard(
                    openIncomes: { navigation.section = .incomes },
                    openExpenses: { navigation.section = .expenses }
                )
                entriesCard(summary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .readableWidth(LayoutConstants.contentWidth)
        }
    }

    private func entriesCard(_ summary: HomeMonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lançamentos de \(IncomeFormat.monthName(summary.month))")
                .font(.headline)
                .padding(.bottom, 6)
            if summary.entries.isEmpty {
                Text("Nenhum lançamento em \(IncomeFormat.monthName(summary.month)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            ForEach(summary.entries) { entry in
                TransactionRow(entry: entry)
                if entry.id != summary.entries.last?.id {
                    Divider()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}
