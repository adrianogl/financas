import Foundation

struct ExpensePartsHistory: Equatable {
    let columns: [ExpensePart]
    let rows: [ExpensePartsHistoryRow]

    static func make(occurrence: ExpenseOccurrence, snapshot: ExpenseSnapshot) -> ExpensePartsHistory {
        let expense = occurrence.expense
        let parts = snapshot.parts.filter { $0.expenseID == expense.id }
        var rows: [ExpensePartsHistoryRow] = []
        var cursor = occurrence.month
        while rows.count <= DetailConstants.historyMonths, cursor >= expense.startMonth {
            let amounts = cursor == occurrence.month
                ? Dictionary(occurrence.parts.map { ($0.part.id, $0.amount) }, uniquingKeysWith: { first, _ in first })
                : registered(parts, in: cursor, snapshot: snapshot)
            let current = registered(parts, in: cursor, snapshot: snapshot)
            let previous = registered(parts, in: cursor.previous, snapshot: snapshot)
            let increased = parts.filter { part in
                guard let amount = current[part.id], let before = previous[part.id],
                      ExpensePartSchedule.term(for: part, in: cursor, snapshot: snapshot)?.isFixed == false else { return false }
                return amount > before
            }
            rows.append(ExpensePartsHistoryRow(
                month: cursor,
                amounts: amounts,
                total: total(amounts, expense: expense, in: cursor, snapshot: snapshot),
                increased: Set(increased.map(\.id))
            ))
            cursor = cursor.previous
        }
        let used = Set(rows.flatMap(\.amounts.keys))
        let columns = parts.filter { used.contains($0.id) }.sorted { $0.position < $1.position }
        return ExpensePartsHistory(columns: columns, rows: rows)
    }

    private static func registered(_ parts: [ExpensePart], in month: YearMonth, snapshot: ExpenseSnapshot) -> [UUID: Decimal] {
        var amounts: [UUID: Decimal] = [:]
        for part in parts {
            let bill = snapshot.partBills.first { $0.partID == part.id && $0.month == month }
            if let amount = bill?.paidAmount ?? bill?.billAmount {
                amounts[part.id] = amount
            }
        }
        return amounts
    }

    private static func total(_ amounts: [UUID: Decimal], expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal? {
        guard amounts.isEmpty else { return amounts.values.reduce(0, +) }
        let bill = snapshot.bills.first { $0.expenseID == expense.id && $0.month == month }
        return bill?.paidAmount ?? bill?.billAmount
    }
}
