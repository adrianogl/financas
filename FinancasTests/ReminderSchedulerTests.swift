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

    @Test func asksOnceWhenThereAreEntries() async {
        let center = FakeReminderCenter()
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        #expect(center.requests == 1)
    }

    @Test func entriesExistWithOnlyExpenses() {
        #expect(ReminderEntries.exist(incomes: .empty, expenses: ExpenseSamples.snapshot))
    }

    @Test func entriesExistWithOnlyIncomes() {
        #expect(ReminderEntries.exist(incomes: IncomeSamples.snapshot, expenses: .empty))
    }

    @Test func noEntriesWithoutIncomesAndExpenses() {
        #expect(!ReminderEntries.exist(incomes: .empty, expenses: .empty))
    }

    @Test func doesNotAskWithoutIncomes() async {
        let center = FakeReminderCenter()
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasEntries: false)
        #expect(center.requests == 0)
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        #expect(center.requests == 1)
    }

    @Test func doesNotAskAgainAfterDenied() async {
        let center = FakeReminderCenter(status: .denied)
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        center.status = .notDetermined
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        #expect(center.requests == 0)
    }

    @Test func reschedulesOnlyWhenAllowed() async {
        for status in [ReminderAuthorization.notDetermined, .denied] {
            let center = FakeReminderCenter(status: status)
            await makeScheduler(center).reschedule(items: items, settings: .standard, clearingDelivered: true)
            #expect(center.pending.isEmpty)
            #expect(center.replaceCalls == 0)
            #expect(center.deliveredRemoved == 0)
        }
    }

    @Test func rescheduleReplacesPendingAndClearsDelivered() async {
        let center = FakeReminderCenter(status: .allowed)
        await makeScheduler(center).reschedule(items: items, settings: .standard, clearingDelivered: true)
        #expect(center.pending == ReminderPlanner.plan(items: items, settings: .standard, now: now, calendar: calendar))
        #expect(!center.pending.isEmpty)
        #expect(center.deliveredRemoved == 1)
    }

    @Test func backgroundRescheduleKeepsDelivered() async {
        let center = FakeReminderCenter(status: .allowed)
        await makeScheduler(center).reschedule(items: items, settings: .standard, clearingDelivered: false)
        #expect(center.replaceCalls == 1)
        #expect(center.deliveredRemoved == 0)
    }

    @Test func schedulesAfterPermissionGrantedInSettings() async {
        let center = FakeReminderCenter(status: .denied)
        let scheduler = makeScheduler(center)
        await scheduler.reschedule(items: items, settings: .standard, clearingDelivered: false)
        #expect(center.pending.isEmpty)
        center.status = .allowed
        await scheduler.reschedule(items: items, settings: .standard, clearingDelivered: false)
        #expect(!center.pending.isEmpty)
    }

    @Test func resetRemovesEverything() async {
        let center = FakeReminderCenter(status: .allowed)
        let scheduler = makeScheduler(center)
        await scheduler.reschedule(items: items, settings: .standard, clearingDelivered: false)
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
        let first = Task { await scheduler.reschedule(items: items, settings: .standard, clearingDelivered: false) }
        let second = Task { await scheduler.reschedule(items: later, settings: .standard, clearingDelivered: false) }
        await first.value
        await second.value
        #expect(center.replaceLog == ["start", "end", "start", "end"])
        #expect(center.pending == ReminderPlanner.plan(items: later, settings: .standard, now: now, calendar: calendar))
    }

    @Test func settingsPermissionRequestIgnoresAskedFlag() async {
        let center = FakeReminderCenter(status: .notDetermined)
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionIfNeeded(hasEntries: false)
        await scheduler.requestPermissionFromSettings()
        #expect(center.requests == 1)
    }

    @Test func settingsPermissionRequestSkipsWhenDecided() async {
        let center = FakeReminderCenter(status: .denied)
        await makeScheduler(center).requestPermissionFromSettings()
        #expect(center.requests == 0)
    }

    @Test func settingsPermissionRequestMarksAsAsked() async {
        let center = FakeReminderCenter(status: .notDetermined, grantsOnRequest: false)
        let scheduler = makeScheduler(center)
        await scheduler.requestPermissionFromSettings()
        await scheduler.requestPermissionIfNeeded(hasEntries: true)
        #expect(center.requests == 1)
    }

    @Test func exposesAuthorization() async {
        #expect(await makeScheduler(FakeReminderCenter(status: .denied)).authorization() == .denied)
    }
}
