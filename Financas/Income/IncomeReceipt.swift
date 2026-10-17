import Foundation

struct IncomeReceipt: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let incomeID: UUID
    let month: YearMonth
    var receivedOn: CalendarDay
    var amount: Decimal
    var workedDays: Int?
    var workedHours: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case incomeID = "income_id"
        case month
        case receivedOn = "received_on"
        case amount
        case workedDays = "worked_days"
        case workedHours = "worked_hours"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(incomeID, forKey: .incomeID)
        try container.encode(month, forKey: .month)
        try container.encode(receivedOn, forKey: .receivedOn)
        try container.encode(amount, forKey: .amount)
        try container.encode(workedDays, forKey: .workedDays)
        try container.encode(workedHours, forKey: .workedHours)
    }
}
