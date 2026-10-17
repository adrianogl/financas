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

    @Test func reschedulesWithSessionAndFreshData() async {
        let (store, service) = await loadedStore()
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, store: store) { scheduled.append($0) }

        #expect(service.calls == ["load", "load"])
        #expect(scheduled.count == 1)
        #expect(scheduled.first?.isEmpty == false)
    }

    @Test func skipsWithoutSession() async {
        let (store, service) = await loadedStore()
        service.snapshot = .empty
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { false }, store: store) { scheduled.append($0) }

        #expect(service.calls == ["load"])
        #expect(scheduled.isEmpty)
    }

    @Test func skipsWhenRefreshFails() async {
        let (store, service) = await loadedStore()
        service.nextError = .network
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, store: store) { scheduled.append($0) }

        #expect(scheduled.isEmpty)
    }

    @Test func skipsWhenFirstLoadFails() async {
        let service = FakeIncomeService(snapshot: S.snapshot)
        service.nextError = .network
        let store = IncomeStore(service: service, today: { S.today })
        var scheduled: [[DueItem]] = []

        await BackgroundReminderRefresh.run(hasSession: { true }, store: store) { scheduled.append($0) }

        #expect(scheduled.isEmpty)
    }
}
