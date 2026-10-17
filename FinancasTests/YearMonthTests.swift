import Foundation
import Testing
@testable import Financas

struct YearMonthTests {
    @Test func previousOfJanuaryIsDecember() {
        #expect(YearMonth(year: 2027, month: 1).previous == YearMonth(year: 2026, month: 12))
        #expect(YearMonth(year: 2026, month: 12).next == YearMonth(year: 2027, month: 1))
    }

    @Test func dayClampsToLastDay() {
        #expect(YearMonth(year: 2026, month: 2).day(31) == CalendarDay(year: 2026, month: 2, day: 28))
        #expect(YearMonth(year: 2028, month: 2).day(31).day == 29)
    }

    @Test func rangeIsInclusive() {
        let november = YearMonth(year: 2026, month: 11)
        #expect(YearMonth.range(from: november, through: YearMonth(year: 2027, month: 1)).count == 3)
        #expect(YearMonth.range(from: november, through: YearMonth(year: 2026, month: 10)).isEmpty)
    }

    @Test func codesAsDateStrings() throws {
        let encoder = JSONEncoder()
        let day = try encoder.encode(CalendarDay(year: 2026, month: 11, day: 3))
        let month = try encoder.encode(YearMonth(year: 2026, month: 10))
        #expect(String(decoding: day, as: UTF8.self) == "\"2026-11-03\"")
        #expect(String(decoding: month, as: UTF8.self) == "\"2026-10-01\"")

        let decoded = try JSONDecoder().decode(YearMonth.self, from: Data("\"2026-10-01\"".utf8))
        #expect(decoded == YearMonth(year: 2026, month: 10))
        let decodedDay = try JSONDecoder().decode(CalendarDay.self, from: Data("\"2026-11-03\"".utf8))
        #expect(decodedDay == CalendarDay(year: 2026, month: 11, day: 3))
    }

    @Test func calendarDayOrdersAndAddsDays() {
        let last = CalendarDay(year: 2026, month: 12, day: 31)
        #expect(last.adding(days: 1) == CalendarDay(year: 2027, month: 1, day: 1))
        #expect(CalendarDay(year: 2026, month: 10, day: 15) < CalendarDay(year: 2026, month: 10, day: 16))
        #expect(CalendarDay(year: 2026, month: 11, day: 15).weekday == 1)
        #expect(last.yearMonth == YearMonth(year: 2026, month: 12))
    }
}
