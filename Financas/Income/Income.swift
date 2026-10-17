import Foundation

struct Income: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var kind: IncomeKind
    var dayOfMonth: Int?
    var hoursPerDay: Decimal?
    var startMonth: YearMonth?
    var endMonth: YearMonth?
    var oneOffDate: CalendarDay?
    var oneOffAmount: Decimal?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case dayOfMonth = "day_of_month"
        case hoursPerDay = "hours_per_day"
        case startMonth = "start_month"
        case endMonth = "end_month"
        case oneOffDate = "one_off_date"
        case oneOffAmount = "one_off_amount"
    }
}
