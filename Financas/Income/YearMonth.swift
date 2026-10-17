import Foundation

struct YearMonth: Hashable, Comparable, Codable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(from decoder: Decoder) throws {
        let day = try CalendarDay(from: decoder)
        self.init(year: day.year, month: day.month)
    }

    func encode(to encoder: Encoder) throws {
        try day(1).encode(to: encoder)
    }

    var previous: YearMonth {
        month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1)
    }

    var next: YearMonth {
        month == 12 ? YearMonth(year: year + 1, month: 1) : YearMonth(year: year, month: month + 1)
    }

    var dayCount: Int {
        let first = CalendarDay.calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
        return CalendarDay.calendar.range(of: .day, in: .month, for: first)?.count ?? 28
    }

    func day(_ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: min(max(day, 1), dayCount))
    }

    static func range(from start: YearMonth, through end: YearMonth) -> [YearMonth] {
        var months: [YearMonth] = []
        var current = start
        while current <= end {
            months.append(current)
            current = current.next
        }
        return months
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}
