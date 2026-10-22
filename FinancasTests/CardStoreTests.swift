import Foundation
import Testing
@testable import Financas

@MainActor
struct CardStoreTests {
    private let c6 = CardSamples.c6
    private let caixa = CardSamples.caixa

    private func monthly(_ account: CardAccount, _ description: String, _ amount: Decimal) -> [CardTransaction] {
        (5...10).map { CardSamples.tx(account, 2026, $0, 10, amount, description) }
    }

    private func installment(_ account: CardAccount, _ description: String) -> CardTransaction {
        CardSamples.tx(account, 2026, 10, 5, 100, description, installment: (2, 4), purchase: CardSamples.day(2026, 9, 5))
    }

    private func snapshot(
        transactions: [CardTransaction] = [],
        recurrences: [CardRecurrence] = [],
        accounts: [CardAccount]? = nil,
        connections: [CardConnection] = []
    ) -> CardSnapshot {
        CardSnapshot(connections: connections, accounts: accounts ?? [c6, caixa], transactions: transactions, recurrences: recurrences)
    }

    private func makeStore(_ snapshot: CardSnapshot = .empty) async -> (CardStore, FakeCardService) {
        let service = FakeCardService(snapshot: snapshot)
        let store = CardStore(service: service, today: CardSamples.today)
        await store.load()
        return (store, service)
    }

    private func recurrence(_ account: CardAccount, _ name: String, _ status: CardRecurrenceStatus, ended: CalendarDay? = nil) -> CardRecurrence {
        CardRecurrence(id: UUID(), cardAccountID: account.id, merchantKey: MerchantKey.make(name), status: status, endedOn: ended)
    }

    @Test func filterLimitsEverything() async {
        let transactions = monthly(c6, "Wellhub", 183.30) + monthly(caixa, "Netflix", 55.90)
            + [installment(c6, "Loja C6"), installment(caixa, "Loja Caixa")]
        let confirmed = recurrence(c6, "Spotify", .confirmed)
        let spotify = [CardSamples.tx(c6, 2026, 10, 1, 40, "Spotify")]
        let (store, _) = await makeStore(snapshot(transactions: transactions + spotify, recurrences: [confirmed]))
        #expect(store.plans.count == 2)
        #expect(store.candidates.count == 2)
        store.filter = .account(c6.id)
        #expect(store.plans.map(\.name) == ["Loja C6"])
        #expect(store.candidates.map(\.name) == ["Wellhub"])
        #expect(store.fixedCharges.map(\.name) == ["Spotify"])
        #expect(store.months[0].installments == 100)
        #expect(store.months[0].fixed == 40)
        store.filter = .account(caixa.id)
        #expect(store.fixedCharges.isEmpty)
        #expect(store.months[0].fixed == 0)
        #expect(store.months[0].installments == 100)
    }

    @Test func monthsStartNextMonthAndHaveTwelve() async {
        let (store, _) = await makeStore(snapshot(transactions: [installment(c6, "Loja")]))
        #expect(store.months.count == 12)
        #expect(store.months[0].month == YearMonth(year: 2026, month: 11))
    }

    @Test func removedAccountResetsFilter() async {
        let transactions = [installment(c6, "Loja C6"), installment(caixa, "Loja Caixa")]
        let (store, service) = await makeStore(snapshot(transactions: transactions))
        store.filter = .account(c6.id)
        service.snapshot = snapshot(transactions: [installment(caixa, "Loja Caixa")], accounts: [caixa])
        await store.load()
        #expect(store.filter == .all)
        #expect(store.plans.allSatisfy { $0.cardAccountID != c6.id })
    }

    @Test func finishedPlansAreExcluded() async {
        let old = CardSamples.tx(c6, 2026, 4, 5, 100, "Velha", installment: (2, 4), purchase: CardSamples.day(2026, 3, 5))
        let (store, _) = await makeStore(snapshot(transactions: [old, installment(c6, "Nova")]))
        #expect(store.plans.map(\.name) == ["Nova"])
    }

    @Test func decideConfirmedSavesAndRemovesCandidate() async throws {
        let (store, service) = await makeStore(snapshot(transactions: monthly(c6, "Wellhub", 183.30)))
        let candidate = try #require(store.candidates.first)
        #expect(store.reviewCount == 1)
        await store.decide(candidate, isFixed: true)
        #expect(service.lastSavedRecurrence?.status == .confirmed)
        #expect(service.lastSavedRecurrence?.merchantKey == candidate.merchantKey)
        #expect(service.lastSavedRecurrence?.endedOn == nil)
        #expect(store.reviewCount == 0)
        #expect(store.fixedCharges.count == 1)
    }

    @Test func decideDismissedSavesDismissed() async throws {
        let (store, service) = await makeStore(snapshot(transactions: monthly(c6, "Wellhub", 183.30)))
        await store.decide(try #require(store.candidates.first), isFixed: false)
        #expect(service.lastSavedRecurrence?.status == .dismissed)
        #expect(store.fixedCharges.isEmpty)
    }

    @Test func decideReusesIDOfEndedDecision() async throws {
        let ended = recurrence(c6, "Wellhub", .ended, ended: CardSamples.day(2026, 7, 1))
        let (store, service) = await makeStore(snapshot(transactions: monthly(c6, "Wellhub", 183.30), recurrences: [ended]))
        await store.decide(try #require(store.candidates.first), isFixed: true)
        #expect(service.lastSavedRecurrence?.id == ended.id)
        #expect(store.snapshot.recurrences.count == 1)
        #expect(store.snapshot.recurrences.first?.endedOn == nil)
    }

    @Test func decideFailureRestoresStateAndSetsMessage() async throws {
        let (store, service) = await makeStore(snapshot(transactions: monthly(c6, "Wellhub", 183.30)))
        let candidate = try #require(store.candidates.first)
        service.nextError = .unknown
        await store.decide(candidate, isFixed: true)
        #expect(store.reviewCount == 1)
        #expect(store.snapshot.recurrences.isEmpty)
        #expect(store.errorMessage == IncomeError.unknown.message)
    }

    @Test func endSavesEndedWithToday() async throws {
        let confirmed = recurrence(c6, "Spotify", .confirmed)
        let spotify = [CardSamples.tx(c6, 2026, 10, 1, 40, "Spotify")]
        let (store, service) = await makeStore(snapshot(transactions: spotify, recurrences: [confirmed]))
        await store.end(try #require(store.fixedCharges.first))
        #expect(service.lastSavedRecurrence?.status == .ended)
        #expect(service.lastSavedRecurrence?.endedOn == CardSamples.today)
        #expect(service.lastSavedRecurrence?.id == confirmed.id)
        #expect(store.fixedCharges.isEmpty)
    }

    @Test func loadAsksThirteenMonths() async {
        let (_, service) = await makeStore()
        #expect(service.lastSince == CardSamples.day(2025, 9, 1))
    }

    @Test func loadFailureSetsMessage() async {
        let service = FakeCardService()
        service.nextError = .unknown
        let store = CardStore(service: service, today: CardSamples.today)
        await store.load()
        #expect(store.loadState == .failed(CardConstants.loadFailedMessage))
    }

    @Test func refreshSyncsThenReloads() async {
        let (store, service) = await makeStore()
        let ok = await store.refresh()
        #expect(ok)
        #expect(service.calls == ["load", "sync", "load"])
    }

    @Test func refreshReloadsEvenWhenSyncFails() async {
        let (store, service) = await makeStore()
        service.nextError = .unknown
        service.snapshot = snapshot(transactions: [installment(c6, "Nova")])
        let ok = await store.refresh()
        #expect(!ok)
        #expect(service.calls == ["load", "sync", "load"])
        #expect(store.plans.count == 1)
        #expect(store.errorMessage == CardConstants.syncFailedMessage)
        #expect(store.loadState == .loaded)
    }

    @Test func renameTrimsAndEmptyDoesNotCall() async {
        let (store, service) = await makeStore(snapshot())
        await store.rename(c6, to: "  Principal ")
        #expect(service.lastRename?.nickname == "Principal")
        #expect(store.accounts.first { $0.id == c6.id }?.nickname == "Principal")
        await store.rename(c6, to: "   ")
        #expect(service.calls.filter { $0 == "rename" }.count == 1)
    }

    @Test func connectRegisterAndRemoveCallService() async {
        let connection = CardConnection(id: CardSamples.connection, itemID: "item-1", status: .active, lastSyncedAt: nil, lastError: nil)
        let (store, service) = await makeStore(snapshot(connections: [connection]))
        let token = await store.connectToken(for: connection)
        #expect(token == "token")
        #expect(service.lastTokenItemID == "item-1")
        _ = await store.connectToken(for: nil)
        #expect(service.lastTokenItemID == nil)
        await store.register(itemID: "item-2")
        #expect(service.lastRegisteredItemID == "item-2")
        await store.remove(connection)
        #expect(service.lastRemovedConnectionID == connection.id)
        #expect(service.calls.suffix(2) == ["remove", "load"])
    }

    @Test func oldestSyncIsMinimum() async {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 5000)
        let a = CardConnection(id: UUID(), itemID: "a", status: .active, lastSyncedAt: late, lastError: nil)
        let b = CardConnection(id: UUID(), itemID: "b", status: .active, lastSyncedAt: early, lastError: nil)
        let c = CardConnection(id: UUID(), itemID: "c", status: .active, lastSyncedAt: nil, lastError: nil)
        let (store, _) = await makeStore(snapshot(connections: [a, b, c]))
        #expect(store.oldestSync == early)
    }
}
