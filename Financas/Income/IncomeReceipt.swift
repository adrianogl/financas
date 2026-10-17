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
}
