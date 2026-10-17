import Foundation
import Testing
@testable import Financas

@MainActor
struct ReminderSchedulerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    private var items: [DueItem] {
        let today = CalendarDay(date: now, calendar: calendar)
        return [DueItem(id: "a", kind: .income, title: "Salário", amount: 100, dueDate: today.adding(days: -1))]
    }

    private func makeScheduler(_ center: FakeReminderCenter) -> ReminderScheduler {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        return ReminderScheduler(center: center, defaults: defaults, now: { now }, calendar: calendar)
    }

    @Test func asksOnceWhenThereAreIncomes() async {
        let center = FakeReminderCenter()
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasIncomes: true)
        await scheduler.requestPermissionIfNeeded(hasIncomes: true)
        #expect(center.requests == 1)
    }

    @Test func doesNotAskWithoutIncomes() async {
        let center = FakeReminderCenter()
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasIncomes: false)
        #expect(center.requests == 0)
        await scheduler.requestPermissionIfNeeded(hasIncomes: true)
        #expect(center.requests == 1)
    }

    @Test func doesNotAskAgainAfterDenied() async {
        let center = FakeReminderCenter(status: .denied)
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasIncomes: true)
        center.status = .notDetermined
        await scheduler.requestPermissionIfNeeded(hasIncomes: true)
        #expect(center.requests == 0)
    }

    @Test func reschedulesOnlyWhenAllowed() async {
        for status in [ReminderAuthorization.notDetermined, .denied] {
            let center = FakeReminderCenter(status: status)
            await makeScheduler(center).reschedule(items: items, clearingDelivered: true)
            #expect(center.pending.isEmpty)
            #expect(center.replaceCalls == 0)
            #expect(center.deliveredRemoved == 0)
        }
    }

    @Test func rescheduleReplacesPendingAndClearsDelivered() async {
        let center = FakeReminderCenter(status: .allowed)
        await makeScheduler(center).reschedule(items: items, clearingDelivered: true)
        #expect(center.pending == ReminderPlanner.plan(items: items, now: now, calendar: calendar))
        #expect(!center.pending.isEmpty)
        #expect(center.deliveredRemoved == 1)
    }

    @Test func backgroundRescheduleKeepsDelivered() async {
        let center = FakeReminderCenter(status: .allowed)
        await makeScheduler(center).reschedule(items: items, clearingDelivered: false)
        #expect(center.replaceCalls == 1)
        #expect(center.deliveredRemoved == 0)
    }

    @Test func schedulesAfterPermissionGrantedInSettings() async {
        let center = FakeReminderCenter(status: .denied)
        let scheduler = makeScheduler(center)
        await scheduler.reschedule(items: items, clearingDelivered: false)
        #expect(center.pending.isEmpty)
        center.status = .allowed
        await scheduler.reschedule(items: items, clearingDelivered: false)
        #expect(!center.pending.isEmpty)
    }

    @Test func resetRemovesEverything() async {
        let center = FakeReminderCenter(status: .allowed)
        let scheduler = makeScheduler(center)
        await scheduler.reschedule(items: items, clearingDelivered: false)
        await scheduler.reset()
        #expect(center.removedAll == 1)
        #expect(center.pending.isEmpty)
    }

    @Test func concurrentReschedulesRunOneAtATime() async {
        let center = FakeReminderCenter(status: .allowed)
        center.replaceSuspensions = 5
        let scheduler = makeScheduler(center)
        let today = CalendarDay(date: now, calendar: calendar)
        let later = [DueItem(id: "b", kind: .income, title: "Aluguel", amount: 50, dueDate: today)]
        let first = Task { await scheduler.reschedule(items: items, clearingDelivered: false) }
        let second = Task { await scheduler.reschedule(items: later, clearingDelivered: false) }
        await first.value
        await second.value
        #expect(center.replaceLog == ["start", "end", "start", "end"])
        #expect(center.pending == ReminderPlanner.plan(items: later, now: now, calendar: calendar))
    }
}
