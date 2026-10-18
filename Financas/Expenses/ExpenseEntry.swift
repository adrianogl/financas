import Foundation

struct ExpenseEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let expenseID: UUID
    var spentOn: CalendarDay
    var amount: Decimal

    enum CodingKeys: String, CodingKey {
        case id
        case expenseID = "expense_id"
        case spentOn = "spent_on"
        case amount
    }
}
