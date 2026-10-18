import Foundation
import Testing
@testable import Financas

@MainActor
struct ExpenseStoreTests {
    typealias S = ExpenseSamples

    private func makeStore(_ snapshot: ExpenseSnapshot = S.snapshot) async -> (ExpenseStore, FakeExpenseService) {
        let service = FakeExpenseService(snapshot: snapshot)
        let store = ExpenseStore(service: service)
        await store.load()
        return (store, service)
    }

    private func occurrence(_ store: ExpenseStore, _ expense: Expense, _ month: YearMonth) throws -> ExpenseOccurrence {
        try #require(store.occurrences(in: month, today: S.today).first { $0.expense.id == expense.id && $0.month == month })
    }

    @Test func loadsSnapshot() async {
        let (store, _) = await makeStore()
        #expect(store.loadState == .loaded)
        #expect(store.snapshot == S.snapshot)
    }

    @Test func loadFailureShowsExpenseMessage() async {
        let service = FakeExpenseService()
        service.nextError = .unknown
        let store = ExpenseStore(service: service)
        await store.load()
        #expect(store.loadState == .failed(ExpenseConstants.loadFailedMessage))
    }

    @Test func networkLoadFailureShowsNetworkMessage() async {
        let service = FakeExpenseService()
        service.nextError = .network
        let store = ExpenseStore(service: service)
        await store.load()
        #expect(store.loadState == .failed(IncomeError.network.message))
    }

    @Test func markPaidWithoutBillCreatesRow() async throws {
        let (store, service) = await makeStore()
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today, mode: .payment)

        let saved = await store.markPaid(draft, for: item)

        #expect(saved)
        #expect(service.calls.last == "saveBill")
        #expect(store.snapshot.bills.count == 1)
        #expect(try occurrence(store, S.internet, S.month(2026, 10)).status == .paid)
    }

    @Test func unmarkPaidKeepsBill() async throws {
        var bill = S.bill(S.internet, S.month(2026, 10), 200, due: S.day(2026, 10, 26))
        bill.paidAmount = 200
        bill.paidOn = S.day(2026, 10, 20)
        var snapshot = S.snapshot
        snapshot.bills = [bill]
        let (store, service) = await makeStore(snapshot)
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today)

        let saved = await store.unmarkPaid(draft, for: item)

        #expect(saved)
        #expect(service.calls.last == "saveBill")
        let kept = try #require(store.snapshot.bills.first)
        #expect(store.snapshot.bills.count == 1)
        #expect(kept.billAmount == 200)
        #expect(kept.paidOn == nil)
        #expect(kept.paidAmount == nil)
    }

    @Test func removeBillOfPaidMonthKeepsPayment() async throws {
        var bill = S.bill(S.internet, S.month(2026, 10), 200, due: S.day(2026, 10, 26))
        bill.paidAmount = 190
        bill.paidOn = S.day(2026, 10, 20)
        var snapshot = S.snapshot
        snapshot.bills = [bill]
        let (store, service) = await makeStore(snapshot)
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today)

        let saved = await store.removeBill(draft, for: item)

        #expect(saved)
        #expect(service.calls.last == "saveBill")
        let kept = try #require(store.snapshot.bills.first)
        #expect(kept.billAmount == nil)
        #expect(kept.paidAmount == 190)
    }

    @Test func unmarkLastRecordDeletesRow() async throws {
        var snapshot = S.snapshot
        snapshot.bills = [S.paid(S.internet, S.month(2026, 10), 200, on: S.day(2026, 10, 20))]
        let (store, service) = await makeStore(snapshot)
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today)

        let saved = await store.unmarkPaid(draft, for: item)

        #expect(saved)
        #expect(service.calls.last == "deleteBill")
        #expect(store.snapshot.bills.isEmpty)
    }

    @Test func saveBillStoresBill() async throws {
        let (store, service) = await makeStore()
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today, mode: .bill)

        let saved = await store.saveBill(draft, for: item)

        #expect(saved)
        #expect(service.calls.last == "saveBill")
        #expect(try occurrence(store, S.internet, S.month(2026, 10)).hasBill)
    }

    @Test func networkErrorKeepsStateAndShowsMessage() async throws {
        let (store, service) = await makeStore()
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        service.nextError = .network

        let saved = await store.markPaid(ExpenseBillDraft(occurrence: item, today: S.today, mode: .payment), for: item)

        #expect(!saved)
        #expect(store.snapshot.bills.isEmpty)
        #expect(store.errorMessage == IncomeError.network.message)
    }

    @Test func ignoresSecondSaveWhileSaving() async throws {
        let (store, service) = await makeStore()
        let item = try occurrence(store, S.internet, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: item, today: S.today, mode: .payment)
        service.holdsResponses = true

        let first = Task { await store.markPaid(draft, for: item) }
        for _ in 0..<10 { await Task.yield() }
        let second = await store.markPaid(draft, for: item)
        service.release()
        let firstSaved = await first.value

        #expect(firstSaved)
        #expect(!second)
        #expect(service.calls.filter { $0 == "saveBill" }.count == 1)
    }

    @Test func saveEditReusesTermForSameMonth() async throws {
        let (store, service) = await makeStore()
        var draft = ExpenseDraft(expense: S.internet, snapshot: store.snapshot, today: S.today)
        draft.estimatedAmount = 250

        let first = await store.save(draft, today: S.today)
        let second = await store.save(draft, today: S.today)

        #expect(first && second)
        #expect(service.calls.filter { $0 == "saveExpense" }.count == 2)
        let terms = store.snapshot.terms.filter { $0.expenseID == S.internet.id && $0.validFrom == S.month(2026, 10) }
        #expect(terms.count == 1)
        #expect(terms.first?.estimatedAmount == 250)
    }

    @Test func saveNewExpenseAppendsExpenseAndTerm() async {
        let (store, _) = await makeStore()
        var draft = ExpenseDraft(today: S.today)
        draft.name = "Academia"
        draft.estimatedAmount = 120

        let saved = await store.save(draft, today: S.today)

        #expect(saved)
        #expect(store.snapshot.expenses.contains { $0.name == "Academia" })
        #expect(store.snapshot.terms.count == S.snapshot.terms.count + 1)
    }

    @Test func invalidDraftShowsMessageWithoutCalling() async {
        let (store, service) = await makeStore()
        let draft = ExpenseDraft(today: S.today)

        let saved = await store.save(draft, today: S.today)

        #expect(!saved)
        #expect(store.errorMessage == draft.validationMessage)
        #expect(service.calls == ["load"])
    }

    @Test func endSetsEndMonthNotBeforeStart() async {
        let (store, _) = await makeStore()

        let saved = await store.end(S.internet, in: S.month(2026, 8))

        #expect(saved)
        #expect(store.snapshot.expenses.first { $0.id == S.internet.id }?.endMonth == S.month(2026, 10))
    }

    @Test func deleteRemovesExpenseTermsAndBills() async {
        var snapshot = S.snapshot
        snapshot.bills = [S.paid(S.luz, S.month(2026, 9), 170, on: S.day(2026, 9, 14))]
        let (store, service) = await makeStore(snapshot)

        let deleted = await store.delete(S.luz)

        #expect(deleted)
        #expect(service.calls.last == "deleteExpense")
        #expect(!store.snapshot.expenses.contains { $0.id == S.luz.id })
        #expect(!store.snapshot.terms.contains { $0.expenseID == S.luz.id })
        #expect(store.snapshot.bills.isEmpty)
    }

    @Test func dueItemsNilBeforeLoad() async {
        let store = ExpenseStore(service: FakeExpenseService())
        #expect(store.dueItems(today: S.today) == nil)
        await store.load()
        #expect(store.dueItems(today: S.today) != nil)
    }

    @Test func dueItemsSkipPaidAndIncludePreviousMonthOverdue() async {
        var snapshot = S.snapshot
        snapshot.bills = [S.paid(S.condominio, S.month(2026, 10), 1150, on: S.day(2026, 10, 12))]
        let (store, _) = await makeStore(snapshot)

        let items = store.dueItems(today: S.today) ?? []

        #expect(!items.contains { $0.title == "Condomínio" && $0.dueDate.yearMonth == S.month(2026, 10) })
        #expect(items.contains { $0.title == "Condomínio" && $0.dueDate.yearMonth == S.month(2026, 11) })
        #expect(items.contains { $0.title == "Internet" && $0.kind == .expense })
        #expect(items.contains { $0.dueDate.yearMonth == S.month(2026, 9) })
        let ids = items.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test func overdueOccurrencesOrderedByDueDateThenName() async {
        let (store, _) = await makeStore()
        let overdue = store.overdueOccurrences(today: S.today)
        #expect(!overdue.isEmpty)
        #expect(overdue.allSatisfy { $0.status == .overdue })
        #expect(overdue.map(\.dueDate) == overdue.map(\.dueDate).sorted())
        #expect(store.overdueTotal(today: S.today) == overdue.map(\.amount).reduce(0, +))
    }

    @Test func activeAndEndedExpensesSortedByName() async {
        var snapshot = S.snapshot
        snapshot.expenses[0].endMonth = S.month(2026, 8)
        let (store, _) = await makeStore(snapshot)

        #expect(store.activeExpenses(today: S.today).map(\.name) == ["Condomínio", "Internet"])
        #expect(store.endedExpenses(today: S.today).map(\.name) == ["Luz"])
    }

    @Test func currentTermAndEstimate() async {
        let (store, _) = await makeStore()
        #expect(store.currentTerm(for: S.luz, today: S.today)?.dayOfMonth == 13)
        #expect(store.currentEstimate(for: S.luz, today: S.today) == .manual(180))
    }

    @Test func resetClearsEverything() async {
        let (store, _) = await makeStore()
        store.reset()
        #expect(store.snapshot == .empty)
        #expect(store.loadState == .idle)
        #expect(store.errorMessage == nil)
        #expect(store.dueItems(today: S.today) == nil)
    }

    @Test func refreshReloadsSnapshot() async {
        let (store, service) = await makeStore()
        service.snapshot = .empty

        let refreshed = await store.refresh()

        #expect(refreshed)
        #expect(store.snapshot == .empty)
    }
}
