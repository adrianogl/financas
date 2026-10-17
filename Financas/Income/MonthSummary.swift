import Foundation

struct MonthSummary: Equatable {
    let received: Decimal
    let remaining: Decimal
    let expected: Decimal
    let overdueCount: Int
    let next: IncomeOccurrence?
}
