import Foundation

struct HomeStats: Equatable {
    let balance: HomeStat
    let receivable: HomeStat
    let payable: HomeStat
    let overdue: HomeStat

    @MainActor
    init(incomes: IncomeStore, expenses: ExpenseStore) {
        let month = incomes.selectedMonth
        let today = incomes.today
        let incomesLoaded = incomes.loadState == .loaded
        let expensesLoaded = expenses.loadState == .loaded
        let bothLoaded = incomesLoaded && expensesLoaded

        if bothLoaded {
            let summary = HomeMonthSummary.make(month: month, snapshot: incomes.snapshot, expenses: expenses.snapshot, today: today)
            balance = HomeStat(title: "Saldo", value: IncomeFormat.currency(summary.balance), caption: HomeStatText.balanceCaption(month), badge: nil, isWarning: false)
            let overdueIncomes = incomes.overdueOccurrences
            let overdueExpenses = expenses.overdueOccurrences(today: today)
            let count = overdueIncomes.count + overdueExpenses.count
            overdue = HomeStat(
                title: "Atrasadas",
                value: "\(count)",
                caption: HomeStatText.overdueNames(overdueIncomes.map(\.income.name) + overdueExpenses.map(\.expense.name)),
                badge: nil,
                isWarning: count > 0
            )
        } else {
            balance = Self.loading("Saldo")
            overdue = Self.loading("Atrasadas")
        }

        if incomesLoaded {
            let summary = incomes.summary(for: month)
            receivable = Self.remaining("Falta receber", remaining: summary.remaining, expected: summary.expected, overdueCount: summary.overdueCount)
        } else {
            receivable = Self.loading("Falta receber")
        }

        if expensesLoaded {
            let summary = expenses.summary(for: month, today: today)
            payable = Self.remaining("Falta pagar", remaining: summary.remaining, expected: summary.expected, overdueCount: summary.overdueCount)
        } else {
            payable = Self.loading("Falta pagar")
        }
    }

    private static func remaining(_ title: String, remaining: Decimal, expected: Decimal, overdueCount: Int) -> HomeStat {
        HomeStat(
            title: title,
            value: IncomeFormat.currency(remaining),
            caption: HomeStatText.expected(expected),
            badge: HomeStatText.overdueBadge(overdueCount),
            isWarning: false
        )
    }

    private static func loading(_ title: String) -> HomeStat {
        HomeStat(title: title, value: HomeConstants.loadingValue, caption: "", badge: nil, isWarning: false)
    }
}
