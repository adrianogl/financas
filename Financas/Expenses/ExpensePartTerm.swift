import Foundation

struct ExpensePartTerm: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let partID: UUID
    var validFrom: YearMonth
    var amount: Decimal
    var isFixed: Bool
    var averageFrom: YearMonth
    var isActive: Bool
    var dayOfMonth: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case partID = "part_id"
        case validFrom = "valid_from"
        case amount
        case isFixed = "is_fixed"
        case averageFrom = "average_from"
        case isActive = "is_active"
        case dayOfMonth = "day_of_month"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(partID, forKey: .partID)
        try container.encode(validFrom, forKey: .validFrom)
        try container.encode(amount, forKey: .amount)
        try container.encode(isFixed, forKey: .isFixed)
        try container.encode(averageFrom, forKey: .averageFrom)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(dayOfMonth, forKey: .dayOfMonth)
    }
}
