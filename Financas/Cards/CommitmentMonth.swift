import Foundation

struct CommitmentMonth: Hashable, Identifiable {
    let month: YearMonth
    let installments: Decimal
    let fixed: Decimal

    var total: Decimal { installments + fixed }
    var id: YearMonth { month }
}
