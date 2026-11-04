import Foundation

struct SpendingMonth: Identifiable, Hashable {
    let expense: Expense
    let month: YearMonth
    let expected: Decimal
    let spent: Decimal
    let remaining: Decimal
    let entries: [ExpenseEntry]

    var hasEstimate: Bool { expected > 0 }
    var isOver: Bool { hasEstimate && spent > expected }
    var excess: Decimal { hasEstimate ? max(spent - expected, 0) : 0 }
    var id: String { "\(expense.id)-\(month.year)-\(month.month)" }
}
