import Foundation

@MainActor
enum BackgroundReminderRefresh {
    static func run(
        hasSession: () async -> Bool,
        incomes: IncomeStore,
        expenses: ExpenseStore,
        reschedule: ([DueItem]) async -> Void
    ) async {
        guard await hasSession() else { return }
        async let expensesRefreshed = expenses.refresh()
        let incomesRefreshed = await incomes.refresh()
        guard await expensesRefreshed, incomesRefreshed else { return }
        guard let incomeItems = incomes.dueItems, let expenseItems = expenses.dueItems(today: incomes.today) else { return }
        await reschedule(incomeItems + expenseItems)
    }
}
