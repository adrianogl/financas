import Foundation

enum SpendingSchedule {
    static func month(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> SpendingMonth? {
        guard expense.kind == .spending,
              expense.startMonth <= month,
              expense.endMonth.map({ month <= $0 }) ?? true,
              let term = ExpenseSchedule.term(for: expense, in: month, snapshot: snapshot) else { return nil }
        let entries = snapshot.entries
            .filter { $0.expenseID == expense.id && $0.spentOn.yearMonth == month }
            .sorted { $0.spentOn > $1.spentOn }
        let spent = entries.map(\.amount).reduce(0, +)
        let remaining = month >= today.yearMonth ? max(term.estimatedAmount - spent, 0) : 0
        return SpendingMonth(
            expense: expense,
            month: month,
            expected: term.estimatedAmount,
            spent: spent,
            remaining: remaining,
            entries: entries
        )
    }

    static func months(in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [SpendingMonth] {
        snapshot.expenses
            .compactMap { self.month(of: $0, in: month, snapshot: snapshot, today: today) }
            .sorted { $0.expense.name.localizedStandardCompare($1.expense.name) == .orderedAscending }
    }

    static func history(of expense: Expense, through month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [SpendingMonth] {
        var result: [SpendingMonth] = []
        var current = month
        while result.count < ExpenseConstants.spendingHistoryMonths, current >= expense.startMonth {
            if let item = self.month(of: expense, in: current, snapshot: snapshot, today: today) {
                result.append(item)
            }
            current = current.previous
        }
        return result.reversed()
    }
}
