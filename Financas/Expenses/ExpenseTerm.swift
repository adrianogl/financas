import Foundation

struct ExpenseTerm: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let expenseID: UUID
    var validFrom: YearMonth
    var estimatedAmount: Decimal
    var dayOfMonth: Int
    var averageFrom: YearMonth

    enum CodingKeys: String, CodingKey {
        case id
        case expenseID = "expense_id"
        case validFrom = "valid_from"
        case estimatedAmount = "estimated_amount"
        case dayOfMonth = "day_of_month"
        case averageFrom = "average_from"
    }
}
