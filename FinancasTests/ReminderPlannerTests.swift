import Foundation
import Testing
@testable import Financas

struct ReminderPlannerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        IncomeSamples.day(year, month, day)
    }

    private func at(_ day: CalendarDay, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))!
    }

    private func item(_ id: String, _ amount: Decimal, due: CalendarDay) -> DueItem {
        DueItem(id: id, kind: .income, title: "Item \(id)", amount: amount, dueDate: due)
    }

    private var salary: DueItem {
        DueItem(id: "s", kind: .income, title: "Salário Acme", amount: 8000, dueDate: day(2026, 10, 5))
    }

    @Test func dueDayThenOverdueFromNextDay() {
        let reminders = ReminderPlanner.plan(
            items: [item("a", 100, due: day(2026, 12, 7))],
            now: at(day(2026, 12, 7), 6),
            calendar: calendar
        )
        let ids = reminders.map(\.id)
        #expect(ids.contains("due-2026-12-07-08"))
        #expect(!ids.contains("overdue-2026-12-07-08"))
        #expect(!ids.contains("overdue-2026-12-07-19"))
        #expect(ids.contains("overdue-2026-12-08-08"))
        #expect(ids.contains("overdue-2026-12-08-19"))
    }

    @Test func oneOffOnSundayIsDueThatDay() {
        let reminders = ReminderPlanner.plan(
            items: [item("a", 100, due: day(2026, 10, 18))],
            now: at(day(2026, 10, 17), 20),
            calendar: calendar
        )
        let ids = reminders.map(\.id)
        #expect(ids.contains("due-2026-10-18-08"))
        #expect(ids.contains("overdue-2026-10-19-08"))
    }

    @Test func overdueEveryDayOfWindow() {
        let reminders = ReminderPlanner.plan(
            items: [salary],
            now: at(day(2026, 10, 7), 6),
            calendar: calendar
        )
        #expect(reminders.count == 28)
        #expect(reminders.allSatisfy { $0.route == .overdue })
        #expect(reminders.map(\.day).min() == day(2026, 10, 7))
        #expect(reminders.map(\.day).max() == day(2026, 10, 20))
    }

    @Test func dueAndOverdueSameMorningAreSeparate() {
        let today = day(2026, 10, 17)
        let reminders = ReminderPlanner.plan(
            items: [item("late", 100, due: day(2026, 10, 1)), item("now", 200, due: today)],
            now: at(today, 6),
            calendar: calendar
        )
        let morning = reminders.filter { $0.day == today && $0.hour == 8 }
        #expect(morning.count == 2)
        #expect(morning.first { $0.id == "overdue-2026-10-17-08" } != nil)
        #expect(morning.first { $0.id == "due-2026-10-17-08" }?.route == .incomes)
    }

    @Test func skipsPastSlots() {
        let today = day(2026, 10, 17)
        let reminders = ReminderPlanner.plan(
            items: [salary],
            now: at(today, 19).addingTimeInterval(60),
            calendar: calendar
        )
        #expect(reminders.allSatisfy { $0.day != today })
    }

    @Test func neverMoreThan42() {
        let today = day(2026, 10, 17)
        var items = (0..<5).map { item("late\($0)", 100, due: day(2026, 9, 1 + $0)) }
        items += (0..<14).map { item("day\($0)", 50, due: today.adding(days: $0)) }
        let reminders = ReminderPlanner.plan(items: items, now: at(today, 6), calendar: calendar)
        #expect(reminders.count <= 42)
    }

    @Test func noItemsNoReminders() {
        #expect(ReminderPlanner.plan(items: [], now: at(day(2026, 10, 17), 6), calendar: calendar).isEmpty)
    }

    @Test func singleOverdueText() {
        let text = ReminderText.overdue([salary])
        #expect(text.title == "Receita atrasada")
        #expect(text.body == "Salário Acme · \(IncomeFormat.currency(8000)), prevista para \(IncomeFormat.shortDate(day(2026, 10, 5))).")
    }

    @Test func manyOverdueText() {
        let items = [
            item("a", 8000, due: day(2026, 10, 5)),
            item("b", 4000, due: day(2026, 10, 6)),
            item("c", 480, due: day(2026, 10, 7)),
        ]
        let text = ReminderText.overdue(items)
        #expect(text.title == "3 receitas atrasadas")
        #expect(text.body == "\(IncomeFormat.currency(12480)) ainda não recebidos.")
    }

    @Test func singleDueTodayText() {
        let text = ReminderText.dueToday([salary])
        #expect(text.title == "Receita prevista para hoje")
        #expect(text.body == "Salário Acme · \(IncomeFormat.currency(8000))")
    }

    @Test func manyDueTodayText() {
        let items = [item("a", 8000, due: day(2026, 10, 5)), item("b", 3000, due: day(2026, 10, 5))]
        let text = ReminderText.dueToday(items)
        #expect(text.title == "2 receitas previstas para hoje")
        #expect(text.body == "\(IncomeFormat.currency(11000)) no total.")
    }
}
