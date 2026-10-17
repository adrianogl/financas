import Foundation
import Testing
@testable import Financas

@MainActor
struct BackgroundReminderRefreshTests {
    typealias S = IncomeSamples

    private func loadedStore() async -> (IncomeStore, FakeIncomeService) {
        let service = FakeIncomeService(snapshot: S.snapshot)
        let store = IncomeStore(service: service, today: { S.today })
        await store.load()
        return (store, service)
    }

    private func loadedExpenseStore() async -> (ExpenseStore, FakeExpenseService) {
        let service = FakeExpenseService()
        let store = ExpenseStore(service: service)
        await store.load()
        return (store, service)
    }

    @Test func reschedulesWithSessionAndFreshData() async {
        let (store, service) = await loadedStore()
        let (expenseStore, expenseService) = await loadedExpenseStore()
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, incomes: store, expenses: expenseStore) { scheduled.append($0) }

        #expect(service.calls == ["load", "load"])
        #expect(expenseService.calls == ["load", "load"])
        #expect(scheduled.first?.contains { $0.kind == .expense } == true)
        #expect(scheduled.count == 1)
        #expect(scheduled.first?.isEmpty == false)
    }

    @Test func skipsWithoutSession() async {
        let (store, service) = await loadedStore()
        let (expenseStore, expenseService) = await loadedExpenseStore()
        service.snapshot = .empty
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { false }, incomes: store, expenses: expenseStore) { scheduled.append($0) }

        #expect(service.calls == ["load"])
        #expect(expenseService.calls == ["load"])
        #expect(scheduled.isEmpty)
    }

    @Test func skipsWhenRefreshFails() async {
        let (store, service) = await loadedStore()
        let (expenseStore, _) = await loadedExpenseStore()
        service.nextError = .network
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, incomes: store, expenses: expenseStore) { scheduled.append($0) }

        #expect(scheduled.isEmpty)
    }

    @Test func skipsWhenFirstLoadFails() async {
        let service = FakeIncomeService(snapshot: S.snapshot)
        service.nextError = .network
        let store = IncomeStore(service: service, today: { S.today })
        let (expenseStore, _) = await loadedExpenseStore()
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, incomes: store, expenses: expenseStore) { scheduled.append($0) }

        #expect(scheduled.isEmpty)
    }

    @Test func skipsWhenExpenseRefreshFails() async {
        let (store, _) = await loadedStore()
        let (expenseStore, expenseService) = await loadedExpenseStore()
        expenseService.nextError = .network
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, incomes: store, expenses: expenseStore) { scheduled.append($0) }

        #expect(scheduled.isEmpty)
    }
}
