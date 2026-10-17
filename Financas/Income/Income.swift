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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(dayOfMonth, forKey: .dayOfMonth)
        try container.encode(hoursPerDay, forKey: .hoursPerDay)
        try container.encode(startMonth, forKey: .startMonth)
        try container.encode(endMonth, forKey: .endMonth)
        try container.encode(oneOffDate, forKey: .oneOffDate)
        try container.encode(oneOffAmount, forKey: .oneOffAmount)
    }
}
