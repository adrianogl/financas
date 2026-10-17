import Testing
@testable import Financas

struct BusinessCalendarTests {
    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    @Test func easterDates() {
        #expect(BusinessCalendar.easter(in: 2026) == day(2026, 4, 5))
        #expect(BusinessCalendar.easter(in: 2027) == day(2027, 3, 28))
    }

    @Test func movableHolidays2026() {
        let holidays = BusinessCalendar.holidays(in: 2026)
        #expect(holidays.isSuperset(of: [day(2026, 2, 16), day(2026, 2, 17), day(2026, 4, 3), day(2026, 6, 4)]))
    }

    @Test func movableHolidays2027() {
        let holidays = BusinessCalendar.holidays(in: 2027)
        #expect(holidays.isSuperset(of: [day(2027, 2, 8), day(2027, 2, 9), day(2027, 3, 26), day(2027, 5, 27)]))
    }

    @Test func fixedHolidays() {
        let holidays = BusinessCalendar.holidays(in: 2026)
        let fixed: Set<CalendarDay> = [
            day(2026, 1, 1), day(2026, 4, 21), day(2026, 5, 1), day(2026, 9, 7), day(2026, 10, 12),
            day(2026, 11, 2), day(2026, 11, 15), day(2026, 11, 20), day(2026, 12, 25),
        ]
        #expect(holidays.isSuperset(of: fixed))
        #expect(holidays.count == 13)
    }

    @Test func nextBusinessDay() {
        #expect(BusinessCalendar.businessDayOnOrAfter(day(2026, 11, 15)) == day(2026, 11, 16))
        #expect(BusinessCalendar.businessDayOnOrAfter(day(2026, 11, 1)) == day(2026, 11, 3))
        #expect(BusinessCalendar.businessDayOnOrAfter(day(2026, 10, 1)) == day(2026, 10, 1))
        #expect(BusinessCalendar.businessDayOnOrAfter(day(2026, 12, 25)) == day(2026, 12, 28))
    }

    @Test func businessDaysPerMonth() {
        #expect(BusinessCalendar.businessDays(in: YearMonth(year: 2026, month: 9)) == 21)
        #expect(BusinessCalendar.businessDays(in: YearMonth(year: 2026, month: 10)) == 21)
        #expect(BusinessCalendar.businessDays(in: YearMonth(year: 2026, month: 11)) == 19)
        #expect(BusinessCalendar.businessDays(in: YearMonth(year: 2026, month: 2)) == 18)
    }
}
