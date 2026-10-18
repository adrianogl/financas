import Foundation

struct DetailHistoryEntry: Equatable, Identifiable {
    let month: YearMonth
    let amount: Decimal?

    var id: YearMonth { month }
}
