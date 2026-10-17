import Foundation

struct ExpenseMonthSummary: Equatable {
    let paid: Decimal
    let remaining: Decimal
    let expected: Decimal
    let overdueCount: Int
    let next: ExpenseOccurrence?
}
