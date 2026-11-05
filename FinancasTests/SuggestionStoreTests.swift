import Foundation
import Testing
@testable import Financas

@MainActor
struct SuggestionStoreTests {
    typealias S = ExpenseSamples

    private let padaria = Expense(id: UUID(), name: "Padaria", startMonth: S.month(2026, 10), kind: .spending)
    private let mercado = Expense(id: UUID(), name: "Mercado", startMonth: S.month(2026, 10), kind: .spending)
    private let device = SuggestionDevice(id: UUID(), name: "iPhone")
    private let occurredAt = Date(timeIntervalSince1970: 1_793_870_000)

    private func suggestion(status: SpendingSuggestionStatus = .pending, merchantKey: String = "PADARIA PAO QUENTE") -> SpendingSuggestion {
        SpendingSuggestion(
            id: UUID(),
            merchant: "PADARIA PAO QUENTE",
            merchantKey: merchantKey,
            card: "Nubank",
            amount: S.money("18.90"),
            occurredAt: occurredAt,
            reporterDevices: [device.id],
            firstDeviceName: "iPhone",
            status: status
        )
    }

    private func makeStore(_ snapshot: SuggestionSnapshot) async -> (SuggestionStore, FakeSuggestionService, ExpenseStore) {
        let service = FakeSuggestionService(snapshot: snapshot)
        let expenses = ExpenseStore(service: FakeExpenseService(snapshot: ExpenseSnapshot(
            expenses: [padaria, mercado], terms: [], bills: [], parts: [], partTerms: [], entries: [], partBills: []
        )))
        await expenses.load()
        let store = SuggestionStore(service: service, expenses: expenses, device: { [device] in device })
        await store.load()
        return (store, service, expenses)
    }

    @Test func reportUsesTheNormalizedMerchantKey() async {
        let (store, service, _) = await makeStore(.empty)

        let report = await store.report(SuggestionPurchase(merchant: "Padaria Pão-Quente", card: "Nubank", amount: S.money("18.90"), occurredAt: occurredAt))

        #expect(service.lastMerchantKey == "PADARIA PAO QUENTE")
        #expect(report?.created == true)
        #expect(store.pending.count == 1)
    }

    @Test func confirmAddsTheEntryToTheMonthSpendings() async throws {
        let pending = suggestion()
        let (store, _, expenses) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: []))

        let result = try #require(await store.confirm(pending, in: padaria))

        #expect(result.already == false)
        #expect(store.pending.isEmpty)
        #expect(expenses.snapshot.entries.map(\.expenseID) == [padaria.id])
        #expect(expenses.snapshot.entries.first?.amount == S.money("18.90"))
        #expect(store.snapshot.rules.first?.expenseID == padaria.id)
    }

    @Test func confirmThatWasAlreadyDoneElsewhereKeepsTheExistingEntry() async throws {
        var launched = suggestion(status: .confirmed)
        launched.expenseID = mercado.id
        launched.entryID = UUID()
        let (store, service, expenses) = await makeStore(SuggestionSnapshot(suggestions: [launched], rules: []))
        service.confirmIsAlready = true

        let result = try #require(await store.confirm(launched, in: padaria))

        #expect(result.already)
        #expect(result.suggestion.expenseID == mercado.id)
        #expect(expenses.snapshot.entries.map(\.id) == [launched.entryID])
        #expect(store.snapshot.rules.isEmpty)
    }

    @Test func confirmKeepsAutoLaunchUnsetUnlessAsked() async {
        let pending = suggestion()
        let (store, service, _) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: []))

        _ = await store.confirm(pending, in: padaria)

        #expect(service.lastAutoLaunch == .some(nil))
        #expect(store.autoLaunches(pending) == false)
    }

    @Test func reopenRemovesTheEntryAndReturnsToPending() async throws {
        let pending = suggestion()
        let (store, _, expenses) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: []))
        _ = try #require(await store.confirm(pending, in: padaria))

        let reopened = await store.reopen(pending)

        #expect(reopened)
        #expect(expenses.snapshot.entries.isEmpty)
        #expect(store.pending.map(\.id) == [pending.id])
    }

    @Test func dismissMovesToIgnored() async {
        let pending = suggestion()
        let (store, _, _) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: []))

        let dismissed = await store.dismiss(pending)

        #expect(dismissed)
        #expect(store.pending.isEmpty)
        #expect(store.dismissed.map(\.id) == [pending.id])
    }

    @Test func failedConfirmKeepsThePendingSuggestion() async {
        let pending = suggestion()
        let (store, service, expenses) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: []))
        service.nextError = .network

        let result = await store.confirm(pending, in: padaria)

        #expect(result == nil)
        #expect(store.pending.count == 1)
        #expect(expenses.snapshot.entries.isEmpty)
        #expect(store.errorMessage == IncomeError.network.message)
    }

    @Test func suggestsTheCategoryFromTheMerchantRule() async {
        let pending = suggestion()
        let rule = MerchantSpendingRule(id: UUID(), merchantKey: pending.merchantKey, expenseID: mercado.id, autoLaunch: true)
        let (store, _, _) = await makeStore(SuggestionSnapshot(suggestions: [pending], rules: [rule]))

        #expect(store.suggestedExpense(for: pending, options: [padaria, mercado]) == mercado)
        #expect(store.autoLaunchExpense(for: pending, options: [padaria, mercado]) == mercado)
    }
}
