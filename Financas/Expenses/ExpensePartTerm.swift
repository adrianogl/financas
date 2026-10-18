import Foundation

struct ExpensePartTerm: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let partID: UUID
    var validFrom: YearMonth
    var amount: Decimal
    var isFixed: Bool
    var averageFrom: YearMonth
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case partID = "part_id"
        case validFrom = "valid_from"
        case amount
        case isFixed = "is_fixed"
        case averageFrom = "average_from"
        case isActive = "is_active"
    }
}
