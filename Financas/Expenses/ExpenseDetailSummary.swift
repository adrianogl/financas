struct ExpenseDetailSummary: Equatable {
    let rule: String
    let history: [DetailHistoryEntry]

    static func make(occurrence: ExpenseOccurrence, snapshot: ExpenseSnapshot) -> ExpenseDetailSummary {
        let expense = occurrence.expense
        let day = ExpenseSchedule.term(for: expense, in: occurrence.month, snapshot: snapshot)?.dayOfMonth
            ?? occurrence.dueDate.day
        var entries: [DetailHistoryEntry] = []
        var cursor = occurrence.month.previous
        while entries.count < DetailConstants.historyMonths, cursor >= expense.startMonth {
            let paid = snapshot.bills.first { $0.expenseID == expense.id && $0.month == cursor }?.paidAmount
            entries.append(DetailHistoryEntry(month: cursor, amount: paid))
            cursor = cursor.previous
        }
        return ExpenseDetailSummary(rule: "Despesa fixa · vence dia \(day)", history: entries)
    }
}
