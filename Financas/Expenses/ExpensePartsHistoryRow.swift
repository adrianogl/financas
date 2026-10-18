import Foundation

struct ExpensePartsHistoryRow: Equatable, Identifiable {
    let month: YearMonth
    let amounts: [UUID: Decimal]
    let total: Decimal?
    let increased: Set<UUID>

    var id: YearMonth { month }
}
