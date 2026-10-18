import Foundation

struct ExpensePart: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let expenseID: UUID
    var name: String
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case expenseID = "expense_id"
        case name
        case position
    }
}
