import Testing
@testable import Financas

struct HomeDayScaleTests {
    @Test func endsOnTheLastDayOfTheMonth() {
        #expect(HomeDayScale.days(in: YearMonth(year: 2026, month: 10)) == [1, 10, 20, 31])
        #expect(HomeDayScale.days(in: YearMonth(year: 2026, month: 2)) == [1, 10, 20, 28])
        #expect(HomeDayScale.days(in: YearMonth(year: 2026, month: 9)) == [1, 10, 20, 30])
    }
}
