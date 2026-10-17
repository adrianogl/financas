import Charts
import SwiftUI

struct HomeView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(AvatarStore.self) private var avatarStore
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var incomeStore = incomeStore
        let month = incomeStore.selectedMonth
        let summary = HomeMonthSummary.make(month: month, snapshot: incomeStore.snapshot, expenses: expenseStore.snapshot, today: incomeStore.today)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    MonthPicker(month: $incomeStore.selectedMonth)
                    balanceCard(summary)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            CollapsingAppLogo(markSize: 44, isVisible: lockManager.isUnlocked)
                .padding(.bottom, 10)
            Text(Greeting.text(hour: Calendar.current.component(.hour, from: .now), name: account.userName ?? ""))
                .font(.largeTitle.bold())
            Text(Greeting.dateText(for: .now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let message = avatarStore.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .padding(.top, 4)
            }
        }
    }

    private func balanceCard(_ summary: HomeMonthSummary) -> some View {
        let domain = summary.chartDomain
        return VStack(alignment: .leading, spacing: 6) {
            Text("Saldo de \(IncomeFormat.monthName(summary.month))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(summary.balance))
                .font(.system(size: 34, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Chart(summary.points) { point in
                AreaMark(
                    x: .value("Dia", point.day),
                    yStart: .value("Base", domain.lowerBound),
                    yEnd: .value("Saldo", point.balance)
                )
                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Dia", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 1...summary.month.dayCount)
            .chartYScale(domain: domain)
            .frame(height: 96)
            .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.smooth, value: summary)
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
