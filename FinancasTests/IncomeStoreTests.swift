import Foundation
import Testing
@testable import Financas

@MainActor
struct IncomeStoreTests {
    typealias S = IncomeSamples

    private func makeStore(_ snapshot: IncomeSnapshot = S.snapshot) async -> (IncomeStore, FakeIncomeService) {
        let service = FakeIncomeService(snapshot: snapshot)
        let store = IncomeStore(service: service, today: { S.today })
        await store.load()
        return (store, service)
    }

    private func hourlyOctober(_ store: IncomeStore) throws -> IncomeOccurrence {
        try #require(store.occurrences(in: S.month(2026, 10)).first { $0.income.id == S.hourly.id && $0.month == S.month(2026, 10) })
    }

    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    @Test func loadsSnapshot() async {
        let (store, _) = await makeStore()
        #expect(store.loadState == .loaded)
        #expect(store.snapshot == S.snapshot)
        #expect(store.selectedMonth == S.month(2026, 10))
    }

    @Test func loadFailureShowsMessage() async {
        let service = FakeIncomeService()
        service.nextError = .network
        let store = IncomeStore(service: service, today: { S.today })
        await store.load()
        #expect(store.loadState == .failed(IncomeError.network.message))
    }

    @Test func markReceivedUpdatesOccurrence() async throws {
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 10), amount: S.money("13020.04"))]
        let (store, service) = await makeStore(snapshot)
        let item = try hourlyOctober(store)

        let saved = await store.markReceived(item, with: ReceiptDraft(occurrence: item, today: S.today))

        #expect(saved)
        #expect(service.calls.last == "saveReceipt")
        #expect(try hourlyOctober(store).status == .received)
        #expect(store.summary(for: S.month(2026, 10)).remaining == 0)
    }

    @Test func networkErrorKeepsState() async throws {
        let (store, service) = await makeStore()
        let item = try hourlyOctober(store)
        service.nextError = .network

        let saved = await store.markReceived(item, with: ReceiptDraft(occurrence: item, today: S.today))

        #expect(!saved)
        #expect(try hourlyOctober(store).status == .overdue)
        #expect(store.errorMessage == IncomeError.network.message)
    }

    @Test func ignoresSecondSaveWhileSaving() async throws {
        let (store, service) = await makeStore()
        let item = try hourlyOctober(store)
        let draft = ReceiptDraft(occurrence: item, today: S.today)
        service.holdsResponses = true

        let first = Task { await store.markReceived(item, with: draft) }
        await settle()
        let second = await store.markReceived(item, with: draft)
        service.release()
        let firstSaved = await first.value

        #expect(firstSaved)
        #expect(!second)
        #expect(service.calls.filter { $0 == "saveReceipt" }.count == 1)
    }

    @Test func unmarkReturnsToOverdue() async throws {
        let (store, service) = await makeStore()
        let item = try hourlyOctober(store)
        _ = await store.markReceived(item, with: ReceiptDraft(occurrence: item, today: S.today))

        let removed = await store.unmarkReceived(try hourlyOctober(store))

        #expect(removed)
        #expect(service.calls.last == "deleteReceipt")
        #expect(try hourlyOctober(store).status == .overdue)
    }

    @Test func saveDraftAddsIncome() async throws {
        let (store, _) = await makeStore(.empty)
        var draft = IncomeDraft(today: S.today)
        draft.name = "Fixa"
        draft.amount = S.money("13020.04")

        let saved = await store.save(draft)

        #expect(saved)
        #expect(store.activeRecurring.map(\.name) == ["Fixa"])
        #expect(store.summary(for: S.month(2026, 11)).expected == S.money("13020.04"))
    }

    @Test func invalidDraftIsNotSent() async {
        let (store, service) = await makeStore(.empty)
        let saved = await store.save(IncomeDraft(today: S.today))
        #expect(!saved)
        #expect(!service.calls.contains("saveIncome"))
        #expect(store.errorMessage == "Dê um nome para a receita.")
    }

    @Test func endKeepsHistory() async {
        let (store, _) = await makeStore()
        let ended = await store.end(S.fixed, in: S.month(2026, 11))
        store.today = S.day(2026, 12, 1)

        #expect(ended)
        #expect(store.endedRecurring.map(\.id) == [S.fixed.id])
        #expect(!store.activeRecurring.map(\.id).contains(S.fixed.id))
        #expect(store.occurrences(in: S.month(2026, 10)).contains { $0.income.id == S.fixed.id })
    }

    @Test func deleteRemovesIncomeAndReceipts() async {
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 10), amount: 1)]
        let (store, service) = await makeStore(snapshot)

        let deleted = await store.delete(S.fixed)

        #expect(deleted)
        #expect(service.calls.last == "deleteIncome")
        #expect(store.snapshot.incomes.map(\.id) == [S.hourly.id])
        #expect(store.snapshot.amounts.allSatisfy { $0.incomeID != S.fixed.id })
        #expect(store.snapshot.receipts.isEmpty)
    }

    @Test func currentMonthListsOverdueFirst() async {
        var hourly = S.hourly
        hourly.startMonth = S.month(2026, 9)
        let rate = IncomeAmount(id: UUID(), incomeID: hourly.id, amount: 90, validFrom: S.month(2026, 8))
        let (store, _) = await makeStore(IncomeSnapshot(incomes: [hourly], amounts: [rate], receipts: []))

        let items = store.occurrences(in: S.month(2026, 10))

        #expect(items.map(\.month) == [S.month(2026, 9), S.month(2026, 10)])
        #expect(store.occurrences(in: S.month(2026, 11)).map(\.month) == [S.month(2026, 11)])
    }

    @Test func currentAmountUsesLatestValidFrom() async {
        var snapshot = S.snapshot
        snapshot.amounts.append(IncomeAmount(id: UUID(), incomeID: S.hourly.id, amount: 100, validFrom: S.month(2026, 12)))
        let (store, _) = await makeStore(snapshot)
        #expect(store.currentAmount(for: S.hourly) == 90)
        store.today = S.day(2026, 12, 5)
        #expect(store.currentAmount(for: S.hourly) == 100)
        #expect(store.currentAmount(for: S.fixed) == S.money("13020.04"))
    }

    @Test func resetDiscardsLoadInFlight() async {
        let service = FakeIncomeService()
        service.holdsResponses = true
        let store = IncomeStore(service: service, today: { S.today })

        let loading = Task { await store.load() }
        await settle()
        store.reset()
        service.release()
        await loading.value

        #expect(store.snapshot == .empty)
        #expect(store.loadState == .idle)
    }

    @Test func resetDiscardsSaveInFlight() async throws {
        let (store, service) = await makeStore()
        let item = try hourlyOctober(store)
        service.holdsResponses = true

        let saving = Task { await store.markReceived(item, with: ReceiptDraft(occurrence: item, today: S.today)) }
        await settle()
        store.reset()
        service.release()
        _ = await saving.value

        #expect(store.snapshot == .empty)
    }

    @Test func refreshMovesTodayAndReloads() async {
        var day = S.today
        let service = FakeIncomeService()
        let store = IncomeStore(service: service, today: { day })
        await store.load()
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 11), amount: 1)]
        service.snapshot = snapshot
        day = S.day(2026, 11, 2)

        await store.refresh()

        #expect(store.today == S.day(2026, 11, 2))
        #expect(store.selectedMonth == S.month(2026, 11))
        #expect(store.snapshot == snapshot)
        #expect(store.loadState == .loaded)
        #expect(service.calls == ["load", "load"])
    }

    @Test func refreshKeepsChosenMonth() async {
        var day = S.today
        let store = IncomeStore(service: FakeIncomeService(), today: { day })
        await store.load()
        store.selectedMonth = S.month(2027, 3)
        day = S.day(2026, 11, 2)

        await store.refresh()

        #expect(store.selectedMonth == S.month(2027, 3))
    }

    @Test func refreshFailureKeepsData() async {
        let (store, service) = await makeStore()
        service.nextError = .network

        await store.refresh()

        #expect(store.snapshot == S.snapshot)
        #expect(store.loadState == .loaded)
    }

    @Test func loadFailureWithUnknownErrorSaysLoad() async {
        let service = FakeIncomeService()
        service.nextError = .unknown
        let store = IncomeStore(service: service, today: { S.today })
        await store.load()
        #expect(store.loadState == .failed(IncomeError.unknown.loadMessage))
        #expect(IncomeError.unknown.loadMessage == "Não foi possível carregar suas receitas. Tente de novo.")
        #expect(IncomeError.network.loadMessage == IncomeError.network.message)
    }

    @Test func resetClearsSnapshot() async {
        let (store, _) = await makeStore()
        store.selectedMonth = S.month(2027, 1)

        store.reset()

        #expect(store.snapshot == .empty)
        #expect(store.loadState == .idle)
        #expect(store.selectedMonth == S.month(2026, 10))
    }
}
