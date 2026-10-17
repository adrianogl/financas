import Testing
@testable import Financas

struct DueTextTests {
    private let today = CalendarDay(year: 2026, month: 10, day: 17)

    @Test func dueTexts() {
        #expect(DueText.text(dueDate: today, today: today) == "vence hoje")
        #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 18), today: today) == "vence 18/10 · daqui a 1 dia")
        #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 25), today: today) == "vence 25/10 · daqui a 8 dias")
        #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 16), today: today) == "atrasada há 1 dia")
        #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 13), today: today) == "atrasada há 4 dias")
    }
}
