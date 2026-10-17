import Foundation
import Testing
@testable import Financas

@MainActor
struct IncomeStoreSettingsTests {
    typealias S = IncomeSamples

    private func makeStore() async -> (IncomeStore, FakeIncomeService) {
        let service = FakeIncomeService(snapshot: S.snapshot)
        let store = IncomeStore(service: service, today: { S.today })
        await store.load()
        return (store, service)
    }

    private var changed: AccountSettings {
        var settings = AccountSettings.standard
        settings.nonBusinessDay = .previous
        return settings
    }

    @Test func updateAppliesImmediately() async {
        let (store, service) = await makeStore()
        service.holdsResponses = true
        let task = store.updateSettings(changed)
        #expect(store.settings == changed)
        for _ in 0..<10 { await Task.yield() }
        #expect(store.isSavingSettings)
        service.release()
        #expect(await task.value)
        #expect(!store.isSavingSettings)
    }

    @Test func savesWithPreviousValue() async throws {
        let (store, service) = await makeStore()
        #expect(await store.updateSettings(changed).value)
        let saved = try #require(service.savedSettings.last)
        #expect(saved.settings == changed)
        #expect(saved.previous == .standard)
    }

    @Test func failedSaveRestoresPrevious() async {
        let (store, service) = await makeStore()
        service.nextError = .network
        #expect(!(await store.updateSettings(changed).value))
        #expect(store.settings == .standard)
        #expect(store.settingsErrorMessage == IncomeError.network.message)
    }

    @Test func successfulSaveClearsError() async {
        let (store, service) = await makeStore()
        service.nextError = .network
        _ = await store.updateSettings(changed).value
        #expect(await store.updateSettings(changed).value)
        #expect(store.settingsErrorMessage == nil)
    }

    @Test func unchangedSettingsDoNotCallService() async {
        let (store, service) = await makeStore()
        #expect(await store.updateSettings(store.settings).value)
        #expect(!service.calls.contains("saveSettings"))
    }

    @Test func resetRestoresStandard() async {
        let (store, _) = await makeStore()
        _ = await store.updateSettings(changed).value
        store.reset()
        #expect(store.settings == .standard)
    }

    @Test func backToBackUpdatesKeepBothChanges() async throws {
        let (store, service) = await makeStore()
        store.updateSettings(changed)
        var second = store.settings
        second.dueTodayEnabled = false
        let last = store.updateSettings(second)
        #expect(await last.value)
        var expected = changed
        expected.dueTodayEnabled = false
        #expect(store.settings == expected)
        let saved = try #require(service.savedSettings.last)
        #expect(saved.settings == expected)
    }

    @Test func quickUpdatesBecomeOneSave() async {
        let (store, service) = await makeStore()
        service.holdsResponses = true
        store.updateSettings(changed)
        var second = changed
        second.dueTodayEnabled = false
        let last = store.updateSettings(second)
        for _ in 0..<10 { await Task.yield() }
        #expect(service.calls.filter { $0 == "saveSettings" }.count == 1)
        service.release()
        #expect(await last.value)
        #expect(service.calls.filter { $0 == "saveSettings" }.count == 1)
        #expect(service.savedSettings.last?.settings == second)
        #expect(service.savedSettings.last?.previous == .standard)
    }
}
