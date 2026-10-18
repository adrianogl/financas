import Foundation

struct ExpenseEntryDraft: Equatable {
    let expense: Expense
    let entryID: UUID
    let isNew: Bool
    var amount: Decimal?
    var spentOn: CalendarDay
    private let today: CalendarDay

    init(expense: Expense, month: YearMonth, today: CalendarDay) {
        self.expense = expense
        self.today = today
        entryID = UUID()
        isNew = true
        amount = nil
        spentOn = month < today.yearMonth ? month.day(month.dayCount) : today
    }

    init(entry: ExpenseEntry, expense: Expense, today: CalendarDay = CalendarDay(date: Date())) {
        self.expense = expense
        self.today = today
        entryID = entry.id
        isNew = false
        amount = entry.amount
        spentOn = entry.spentOn
    }

    var validRange: ClosedRange<CalendarDay> {
        let first = expense.startMonth.day(1)
        let monthEnd = expense.endMonth.map { $0.day($0.dayCount) } ?? today
        let last = max(first, min(today, monthEnd))
        return first...last
    }

    var validationMessage: String? {
        guard let amount, amount > 0 else { return ExpenseConstants.entryAmountMessage }
        guard validRange.contains(spentOn) else { return ExpenseConstants.entryDateMessage }
        return nil
    }

    func build() -> ExpenseEntry {
        ExpenseEntry(id: entryID, expenseID: expense.id, spentOn: spentOn, amount: amount ?? 0)
    }
}
