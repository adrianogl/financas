import Foundation

enum ExpenseEstimate: Hashable {
    case average(amount: Decimal, months: [YearMonth])
    case manual(Decimal)

    var amount: Decimal {
        switch self {
        case .average(let amount, _): amount
        case .manual(let amount): amount
        }
    }
}
