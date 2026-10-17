import Foundation

struct IncomeAmount: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let incomeID: UUID
    var amount: Decimal
    var validFrom: YearMonth

    enum CodingKeys: String, CodingKey {
        case id
        case incomeID = "income_id"
        case amount
        case validFrom = "valid_from"
    }
}
