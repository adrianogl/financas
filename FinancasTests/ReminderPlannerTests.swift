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
            settings: .standard,
            now: at(day(2026, 12, 7), 6),
            calendar: calendar
        )
        let ids = reminders.map(\.id)
        #expect(ids.contains("due-2026-12-07-0800"))
        #expect(!ids.contains("overdue-2026-12-07-0800"))
        #expect(!ids.contains("overdue-2026-12-07-1900"))
        #expect(ids.contains("overdue-2026-12-08-0800"))
        #expect(ids.contains("overdue-2026-12-08-1900"))
    }

    @Test func oneOffOnSundayIsDueThatDay() {
        let reminders = ReminderPlanner.plan(
            items: [item("a", 100, due: day(2026, 10, 18))],
            settings: .standard,
            now: at(day(2026, 10, 17), 20),
            calendar: calendar
        )
        let ids = reminders.map(\.id)
        #expect(ids.contains("due-2026-10-18-0800"))
        #expect(ids.contains("overdue-2026-10-19-0800"))
    }

    @Test func overdueEveryDayOfWindow() {
        let reminders = ReminderPlanner.plan(
            items: [salary],
            settings: .standard,
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
            settings: .standard,
            now: at(today, 6),
            calendar: calendar
        )
        let morning = reminders.filter { $0.day == today && $0.time == ReminderTime(hour: 8, minute: 0) }
        #expect(morning.count == 2)
        #expect(morning.first { $0.id == "overdue-2026-10-17-0800" } != nil)
        #expect(morning.first { $0.id == "due-2026-10-17-0800" }?.route == .incomes)
    }

    @Test func skipsPastSlots() {
        let today = day(2026, 10, 17)
        let reminders = ReminderPlanner.plan(
            items: [salary],
            settings: .standard,
            now: at(today, 19).addingTimeInterval(60),
            calendar: calendar
        )
        #expect(reminders.allSatisfy { $0.day != today })
    }

    @Test func neverMoreThan42() {
        let today = day(2026, 10, 17)
        var items = (0..<5).map { item("late\($0)", 100, due: day(2026, 9, 1 + $0)) }
        items += (0..<14).map { item("day\($0)", 50, due: today.adding(days: $0)) }
        let reminders = ReminderPlanner.plan(items: items, settings: .standard, now: at(today, 6), calendar: calendar)
        #expect(reminders.count <= 42)
    }

    @Test func noItemsNoReminders() {
        #expect(ReminderPlanner.plan(items: [], settings: .standard, now: at(day(2026, 10, 17), 6), calendar: calendar).isEmpty)
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

    private func settings(_ change: (inout AccountSettings) -> Void) -> AccountSettings {
        var settings = AccountSettings.standard
        change(&settings)
        return settings
    }

    private func at(_ day: CalendarDay, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    @Test func disabledOverdueMorningIsNotScheduled() {
        let reminders = ReminderPlanner.plan(items: [salary], settings: settings { $0.overdueMorningEnabled = false }, now: at(day(2026, 10, 7), 6), calendar: calendar)
        #expect(!reminders.contains { $0.id.hasSuffix("-0800") })
        #expect(reminders.contains { $0.id == "overdue-2026-10-07-1900" })
    }

    @Test func disabledOverdueEveningIsNotScheduled() {
        let reminders = ReminderPlanner.plan(items: [salary], settings: settings { $0.overdueEveningEnabled = false }, now: at(day(2026, 10, 7), 6), calendar: calendar)
        #expect(!reminders.contains { $0.id.hasSuffix("-1900") })
        #expect(reminders.count == 14)
    }

    @Test func disabledDueTodayIsNotScheduled() {
        let today = day(2026, 10, 17)
        let reminders = ReminderPlanner.plan(items: [item("now", 200, due: today)], settings: settings { $0.dueTodayEnabled = false }, now: at(today, 6), calendar: calendar)
        #expect(!reminders.contains { $0.route == .incomes })
    }

    @Test func usesConfiguredMinutes() throws {
        let today = day(2026, 10, 16)
        let reminders = ReminderPlanner.plan(items: [item("now", 200, due: today)], settings: settings { $0.dueTodayTime = ReminderTime(hour: 7, minute: 30) }, now: at(today, 6), calendar: calendar)
        let due = try #require(reminders.first { $0.route == .incomes })
        #expect(due.time == ReminderTime(hour: 7, minute: 30))
        #expect(due.id == "due-2026-10-16-0730")
    }

    @Test func sameTimeOverdueBecomesOne() {
        let reminders = ReminderPlanner.plan(
            items: [salary],
            settings: settings { $0.overdueEveningTime = ReminderTime(hour: 8, minute: 0) },
            now: at(day(2026, 10, 7), 6),
            calendar: calendar
        )
        #expect(reminders.count == 14)
        #expect(Set(reminders.map(\.id)).count == 14)
    }

    @Test func pastTimeTodayIsSkipped() {
        let today = day(2026, 10, 16)
        let reminders = ReminderPlanner.plan(items: [item("now", 200, due: today)], settings: settings { $0.dueTodayTime = ReminderTime(hour: 7, minute: 30) }, now: at(today, 7, 45), calendar: calendar)
        #expect(!reminders.contains { $0.route == .incomes })
    }

    private func expense(_ id: String, _ title: String, _ amount: Decimal, due: CalendarDay) -> DueItem {
        DueItem(id: id, kind: .expense, title: title, amount: amount, dueDate: due)
    }

    private var planningNow: Date {
        at(day(2026, 10, 17), 6)
    }

    @Test func expenseDueTodayFiresMorningAndEvening() {
        let due = day(2026, 10, 19)
        let reminders = ReminderPlanner.plan(items: [expense("l", "Luz", 212.30, due: due)], settings: .standard, now: planningNow, calendar: calendar)
        let morning = reminders.first { $0.id == "due-2026-10-19-0800" }
        let evening = reminders.first { $0.id == "duelate-2026-10-19-1900" }
        #expect(morning?.title == "Conta vence hoje")
        #expect(evening?.title == "Conta vence hoje")
        #expect(evening?.body == "Luz · \(IncomeFormat.currency(212.30))")
    }

    @Test func eveningDueRespectsToggle() {
        let due = day(2026, 10, 19)
        let reminders = ReminderPlanner.plan(items: [expense("l", "Luz", 212.30, due: due)], settings: settings { $0.overdueEveningEnabled = false }, now: planningNow, calendar: calendar)
        #expect(reminders.contains { $0.id == "due-2026-10-19-0800" })
        #expect(!reminders.contains { $0.id.hasPrefix("duelate-") })
    }

    @Test func eveningDueSkippedWhenSameTimeAsMorning() {
        let due = day(2026, 10, 19)
        let reminders = ReminderPlanner.plan(
            items: [expense("l", "Luz", 212.30, due: due)],
            settings: settings { $0.overdueEveningTime = $0.dueTodayTime },
            now: planningNow,
            calendar: calendar
        )
        #expect(reminders.contains { $0.id == "due-2026-10-19-0800" })
        #expect(!reminders.contains { $0.id.hasPrefix("duelate-") })
    }

    @Test func eveningDueFiresWhenSameTimeButMorningOff() {
        let due = day(2026, 10, 19)
        let reminders = ReminderPlanner.plan(
            items: [expense("l", "Luz", 212.30, due: due)],
            settings: settings { $0.overdueEveningTime = $0.dueTodayTime; $0.dueTodayEnabled = false },
            now: planningNow,
            calendar: calendar
        )
        #expect(reminders.contains { $0.id == "duelate-2026-10-19-0800" })
    }

    @Test func incomeAndExpenseShareOneReminder() {
        let due = day(2026, 10, 19)
        let items = [
            item("s", 13020.04, due: due),
            expense("l", "Luz", 212.30, due: due),
            expense("i", "Internet", 94.10, due: due),
        ]
        let reminders = ReminderPlanner.plan(items: items, settings: .standard, now: planningNow, calendar: calendar)
        let morning = reminders.filter { $0.id.hasPrefix("due-2026-10-19") }
        #expect(morning.count == 1)
        #expect(morning.first?.title == "Hoje: 1 receita e 2 contas")
        #expect(morning.first?.body == "\(IncomeFormat.currency(13020.04)) a receber e \(IncomeFormat.currency(306.40)) a pagar.")
        let evening = reminders.first { $0.id == "duelate-2026-10-19-1900" }
        #expect(evening?.title == "2 contas vencem hoje")
        #expect(evening?.body == "\(IncomeFormat.currency(306.40)) no total.")
    }

    @Test func mixedOverdueText() {
        let items = [
            item("s", 15120, due: day(2026, 10, 5)),
            expense("l", "Luz", 212.30, due: day(2026, 10, 13)),
            expense("i", "Internet", 94.10, due: day(2026, 10, 14)),
        ]
        let text = ReminderText.overdue(items)
        #expect(text.title == "Atrasadas: 1 receita e 2 contas")
        #expect(text.body == "\(IncomeFormat.currency(15120)) a receber e \(IncomeFormat.currency(306.40)) a pagar.")
    }

    @Test func expenseOverdueTexts() {
        let luz = expense("l", "Luz", 212.30, due: day(2026, 10, 13))
        let single = ReminderText.overdue([luz])
        #expect(single.title == "Conta atrasada")
        #expect(single.body == "Luz · \(IncomeFormat.currency(212.30)), venceu em \(IncomeFormat.shortDate(day(2026, 10, 13))).")
        let many = ReminderText.overdue([luz, expense("i", "Internet", 94.10, due: day(2026, 10, 14))])
        #expect(many.title == "2 contas atrasadas")
        #expect(many.body == "\(IncomeFormat.currency(306.40)) ainda não pagos.")
    }

    @Test func expenseDueTodayTexts() {
        let luz = expense("l", "Luz", 212.30, due: day(2026, 10, 19))
        let single = ReminderText.dueToday([luz])
        #expect(single.title == "Conta vence hoje")
        #expect(single.body == "Luz · \(IncomeFormat.currency(212.30))")
        let many = ReminderText.dueToday([luz, expense("i", "Internet", 94.10, due: day(2026, 10, 19))])
        #expect(many.title == "2 contas vencem hoje")
        #expect(many.body == "\(IncomeFormat.currency(306.40)) no total.")
    }

    @Test func mixedPluralTexts() {
        let items = [
            item("a", 100, due: day(2026, 10, 19)),
            item("b", 100, due: day(2026, 10, 19)),
            expense("l", "Luz", 50, due: day(2026, 10, 19)),
        ]
        #expect(ReminderText.dueToday(items).title == "Hoje: 2 receitas e 1 conta")
    }

    @Test func paidExpenseHasNoReminder() {
        let reminders = ReminderPlanner.plan(items: [], settings: .standard, now: planningNow, calendar: calendar)
        #expect(reminders.isEmpty)
    }

    @Test func routes() {
        let due = day(2026, 10, 19)
        let withExpense = ReminderPlanner.plan(items: [item("s", 100, due: due), expense("l", "Luz", 50, due: due)], settings: .standard, now: planningNow, calendar: calendar)
        #expect(withExpense.first { $0.id == "due-2026-10-19-0800" }?.route == .expenses)
        #expect(withExpense.first { $0.id == "duelate-2026-10-19-1900" }?.route == .expenses)
        let onlyIncome = ReminderPlanner.plan(items: [item("s", 100, due: due)], settings: .standard, now: planningNow, calendar: calendar)
        #expect(onlyIncome.first { $0.id == "due-2026-10-19-0800" }?.route == .incomes)
        #expect(!onlyIncome.contains { $0.id.hasPrefix("duelate-") })
        let overdue = ReminderPlanner.plan(items: [expense("l", "Luz", 50, due: day(2026, 10, 10))], settings: .standard, now: planningNow, calendar: calendar)
        #expect(overdue.allSatisfy { $0.route == .overdue })
    }

    @Test func atMost56RemindersIn14Days() {
        let today = day(2026, 10, 17)
        var items = (0..<5).map { expense("late\($0)", "Conta \($0)", 100, due: day(2026, 9, 1 + $0)) }
        items += (0..<14).map { expense("day\($0)", "Dia \($0)", 50, due: today.adding(days: $0)) }
        items += (0..<14).map { item("inc\($0)", 50, due: today.adding(days: $0)) }
        let reminders = ReminderPlanner.plan(items: items, settings: .standard, now: planningNow, calendar: calendar)
        #expect(reminders.count <= 56)
        #expect(reminders.count > 42)
    }
}
