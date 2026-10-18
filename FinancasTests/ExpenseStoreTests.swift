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

    @Test func saveSendsPartsAndUpdatesSnapshot() async throws {
        let (store, service) = await makeStore()
        var draft = ExpenseDraft(expense: S.condominio, snapshot: store.snapshot, today: S.today)
        draft.addPart()
        draft.parts[0].name = "Taxa"
        draft.parts[0].amount = 820

        let first = await store.save(draft, today: S.today)
        let second = await store.save(draft, today: S.today)

        #expect(first && second)
        let part = try #require(service.lastSavedParts.first)
        #expect(part.name == "Taxa")
        #expect(part.expenseID == S.condominio.id)
        #expect(service.lastSavedPartTerms.map(\.partID) == [part.id])
        #expect(store.snapshot.parts == [part])
        #expect(store.snapshot.partTerms.count == 1)
        #expect(store.snapshot.partTerms.first?.amount == 820)
        #expect(store.snapshot.partTerms.first?.id == service.lastSavedPartTerms.first?.id)
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

    @Test func deleteRemovesPartsTermsAndEntries() async {
        var snapshot = S.snapshot
        let part = ExpensePart(id: UUID(), expenseID: S.luz.id, name: "Taxa", position: 0)
        snapshot.parts = [part]
        snapshot.partTerms = [ExpensePartTerm(
            id: UUID(), partID: part.id, validFrom: S.month(2026, 7), amount: 100,
            isFixed: true, averageFrom: S.month(2026, 7), isActive: true
        )]
        snapshot.entries = [ExpenseEntry(id: UUID(), expenseID: S.luz.id, spentOn: S.day(2026, 10, 1), amount: 20)]
        let (store, _) = await makeStore(snapshot)

        let deleted = await store.delete(S.luz)

        #expect(deleted)
        #expect(store.snapshot.parts.isEmpty)
        #expect(store.snapshot.partTerms.isEmpty)
        #expect(store.snapshot.entries.isEmpty)
    }

    @Test func addEditAndDeleteEntry() async throws {
        let abastecimento = Expense(id: UUID(), name: "Abastecimento", startMonth: S.month(2026, 8), kind: .spending)
        var snapshot = S.snapshot
        snapshot.expenses.append(abastecimento)
        let (store, service) = await makeStore(snapshot)
        var draft = ExpenseEntryDraft(expense: abastecimento, month: S.month(2026, 10), today: S.today)
        draft.amount = 60

        #expect(await store.saveEntry(draft))
        #expect(service.calls.last == "saveEntry")
        #expect(store.snapshot.entries.count == 1)

        var edit = ExpenseEntryDraft(entry: store.snapshot.entries[0], expense: abastecimento, today: S.today)
        edit.amount = 75
        #expect(await store.saveEntry(edit))
        #expect(store.snapshot.entries.count == 1)
        #expect(store.snapshot.entries[0].amount == 75)

        let entry = try #require(store.snapshot.entries.first)
        #expect(await store.deleteEntry(entry))
        #expect(service.calls.last == "deleteEntry")
        #expect(store.snapshot.entries.isEmpty)
    }

    @Test func entryNetworkErrorKeepsSnapshot() async {
        let abastecimento = Expense(id: UUID(), name: "Abastecimento", startMonth: S.month(2026, 8), kind: .spending)
        let entry = ExpenseEntry(id: UUID(), expenseID: abastecimento.id, spentOn: S.day(2026, 10, 1), amount: 20)
        var snapshot = S.snapshot
        snapshot.expenses.append(abastecimento)
        snapshot.entries = [entry]
        let (store, service) = await makeStore(snapshot)
        let before = store.snapshot
        var draft = ExpenseEntryDraft(expense: abastecimento, month: S.month(2026, 10), today: S.today)
        draft.amount = 60

        service.nextError = .network
        #expect(await store.saveEntry(draft) == false)
        #expect(store.snapshot == before)
        #expect(store.errorMessage == IncomeError.network.message)

        service.nextError = .network
        #expect(await store.deleteEntry(entry) == false)
        #expect(store.snapshot == before)
        #expect(store.errorMessage != nil)
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

    @Test func spendingNeverOverdueOrDue() async {
        let abastecimento = Expense(id: UUID(), name: "Abastecimento", startMonth: S.month(2026, 8), kind: .spending)
        let entry = ExpenseEntry(id: UUID(), expenseID: abastecimento.id, spentOn: S.day(2026, 8, 10), amount: 100)
        let snapshot = ExpenseSnapshot(
            expenses: [abastecimento],
            terms: [S.term(abastecimento, from: S.month(2026, 8), day: 1, estimated: 600)],
            bills: [],
            entries: [entry]
        )
        let (store, _) = await makeStore(snapshot)
        #expect(store.overdueOccurrences(today: S.today).isEmpty)
        #expect(store.dueItems(today: S.today)?.isEmpty == true)
        #expect(store.spendings(in: S.month(2026, 10), today: S.today).map(\.expense.name) == ["Abastecimento"])
    }
    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)

    private func partsSnapshot(_ partBills: [ExpensePartBill] = []) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: [],
            parts: [taxa, agua],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 85, day: 15)
            ],
            partBills: partBills
        )
    }

    @Test func overdueTotalUsesRemaining() async {
        let fee = S.partBill(taxa, S.month(2026, 10), paid: 820, on: S.day(2026, 10, 9))
        let (store, _) = await makeStore(partsSnapshot([fee]))
        #expect(store.overdueOccurrences(today: S.today).map(\.expense) == [S.condominio])
        #expect(store.overdueTotal(today: S.today) == 85)
    }

    @Test func markPaidWithPartsSavesPartBills() async throws {
        let launched = S.partBill(agua, S.month(2026, 10), bill: 90, due: S.day(2026, 10, 15))
        let (store, service) = await makeStore(partsSnapshot([launched]))
        let target = try occurrence(store, S.condominio, S.month(2026, 10))
        let draft = ExpenseBillDraft(occurrence: target, today: S.today, mode: .payment)

        #expect(await store.markPaid(draft, for: target))
        #expect(service.calls.last == "savePartBills")
        #expect(store.snapshot.partBills.count == 2)
        #expect(store.snapshot.partBills.first { $0.partID == agua.id }?.id == launched.id)
        #expect(store.snapshot.partBills.first { $0.partID == agua.id }?.paidAmount == 90)
        #expect(store.snapshot.partBills.first { $0.partID == taxa.id }?.paidAmount == 820)

        let paid = try occurrence(store, S.condominio, S.month(2026, 10))
        #expect(await store.unmarkPaid(ExpenseBillDraft(occurrence: paid, today: S.today), for: paid))
        #expect(service.calls.suffix(2) == ["savePartBills", "deletePartBills"])
        #expect(store.snapshot.partBills.map(\.id) == [launched.id])
        #expect(store.snapshot.partBills.first?.paidAmount == nil)
        #expect(store.snapshot.partBills.first?.billAmount == 90)
    }

    @Test func partBillNetworkErrorKeepsSnapshot() async throws {
        let (store, service) = await makeStore(partsSnapshot())
        let before = store.snapshot
        let target = try occurrence(store, S.condominio, S.month(2026, 10))
        service.nextError = .network

        #expect(await store.markPaid(ExpenseBillDraft(occurrence: target, today: S.today, mode: .payment), for: target) == false)
        #expect(store.snapshot == before)
        #expect(store.errorMessage == IncomeError.network.message)
    }

    @Test func deleteRemovesPartBills() async {
        var snapshot = partsSnapshot([S.partBill(agua, S.month(2026, 10), paid: 85)])
        snapshot.expenses += S.snapshot.expenses.filter { $0.id != S.condominio.id }
        let (store, _) = await makeStore(snapshot)

        #expect(await store.delete(S.condominio))
        #expect(store.snapshot.partBills.isEmpty)
    }

    private let gas = S.part(S.condominio, "Gás", position: 2)

    private func threePartsSnapshot(_ partBills: [ExpensePartBill] = [], withLuz: Bool = false) -> ExpenseSnapshot {
        var snapshot = partsSnapshot(partBills)
        snapshot.parts.append(gas)
        snapshot.partTerms.append(S.partTerm(gas, from: S.month(2026, 10), amount: 60, day: 20))
        if withLuz {
            snapshot.expenses.append(S.luz)
            snapshot.terms.append(S.luzTerm)
            snapshot.bills = (7...9).map { S.paid(S.luz, S.month(2026, $0), 180, on: S.day(2026, $0, 13)) }
        }
        return snapshot
    }

    private var paidFee: ExpensePartBill {
        S.partBill(taxa, S.month(2026, 10), paid: 820, on: S.day(2026, 10, 9))
    }

    private func payable(_ store: ExpenseStore, _ part: ExpensePart) throws -> ExpensePayable {
        let target = try occurrence(store, S.condominio, S.month(2026, 10))
        let value = try #require(target.parts.first { $0.part.id == part.id })
        return ExpensePayable(occurrence: target, part: value, today: S.today)
    }

    @Test func overduePayablesSplitParts() async {
        let (store, _) = await makeStore(threePartsSnapshot([paidFee], withLuz: true))

        let overdue = store.overduePayables(today: S.today)

        #expect(overdue.map(\.title) == ["Luz", "Condomínio · Água"])
        #expect(overdue.map(\.amount) == [180, 85])
        #expect(overdue.map(\.dueDate) == [S.day(2026, 10, 13), S.day(2026, 10, 15)])
        #expect(overdue.allSatisfy { $0.status == .overdue })
        #expect(overdue[0].id == overdue[0].occurrence.id)
        #expect(overdue[0].part == nil)
        #expect(overdue[1].part?.part.id == agua.id)
    }

    @Test func dueItemsPerOpenPart() async {
        let (store, _) = await makeStore(threePartsSnapshot([paidFee]))

        let october = (store.dueItems(today: S.today) ?? []).filter { $0.dueDate.yearMonth == S.month(2026, 10) }

        #expect(october.map(\.title) == ["Condomínio · Água", "Condomínio · Gás"])
        #expect(october.map(\.amount) == [85, 60])
        #expect(october.map(\.dueDate) == [S.day(2026, 10, 15), S.day(2026, 10, 20)])
        let ids = (store.dueItems(today: S.today) ?? []).map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test func markPaidWholeBillSavesPartBills() async throws {
        let fee = paidFee
        let (store, service) = await makeStore(threePartsSnapshot([fee]))
        let target = try occurrence(store, S.condominio, S.month(2026, 10))
        var draft = ExpenseBillDraft(occurrence: target, today: S.today, mode: .payment)
        draft.paidOn = S.day(2026, 10, 16)

        #expect(await store.markPaid(draft, for: target))

        #expect(Set(service.lastSavedPartBills.map(\.partID)) == [agua.id, gas.id])
        #expect(store.snapshot.partBills.first { $0.partID == taxa.id } == fee)
        #expect(store.snapshot.partBills.first { $0.partID == agua.id }?.paidOn == S.day(2026, 10, 16))
        #expect(store.snapshot.partBills.first { $0.partID == gas.id }?.paidAmount == 60)
        #expect(try occurrence(store, S.condominio, S.month(2026, 10)).status == .paid)
    }

    @Test func unmarkPartPaidKeepsOtherParts() async throws {
        let water = S.partBill(agua, S.month(2026, 10), paid: 85, on: S.day(2026, 10, 15))
        let (store, service) = await makeStore(threePartsSnapshot([paidFee, water]))
        let target = try payable(store, agua)
        let draft = ExpensePartBillDraft(value: try #require(target.part), today: S.today)

        #expect(await store.unmarkPartPaid(draft, for: target))

        #expect(service.calls.last == "deletePartBills")
        #expect(service.lastDeletedPartBillIDs == [water.id])
        #expect(store.snapshot.partBills.map(\.partID) == [taxa.id])
        let after = try occurrence(store, S.condominio, S.month(2026, 10))
        #expect(after.isPartiallyPaid)
        #expect(after.parts.first { $0.part.id == agua.id }?.status == .overdue)
    }

    @Test func savePartBillLaunchesOnlyThatPart() async throws {
        let (store, service) = await makeStore(threePartsSnapshot([paidFee]))
        let target = try payable(store, gas)
        var draft = ExpensePartBillDraft(value: try #require(target.part), today: S.today, mode: .bill)
        draft.billAmount = 64
        draft.billDueDate = S.day(2026, 10, 22)

        #expect(await store.savePartBill(draft, for: target))

        #expect(service.lastSavedPartBills.map(\.partID) == [gas.id])
        #expect(store.snapshot.partBills.count == 2)
        let gasValue = try occurrence(store, S.condominio, S.month(2026, 10)).parts.first { $0.part.id == gas.id }
        #expect(gasValue?.amount == 64)
        #expect(gasValue?.dueDate == S.day(2026, 10, 22))

        let launched = try payable(store, gas)
        #expect(await store.removePartBill(ExpensePartBillDraft(value: try #require(launched.part), today: S.today), for: launched))
        #expect(store.snapshot.partBills.map(\.partID) == [taxa.id])
    }

    @Test func partBillNetworkErrorKeepsPartBills() async throws {
        let (store, service) = await makeStore(threePartsSnapshot([paidFee]))
        let before = store.snapshot.partBills
        let target = try payable(store, agua)
        service.nextError = .network

        let draft = ExpensePartBillDraft(value: try #require(target.part), today: S.today, mode: .payment)
        #expect(await store.savePartBill(draft, for: target) == false)
        #expect(store.snapshot.partBills == before)
        #expect(store.errorMessage == IncomeError.network.message)
    }

    @Test func removingWhatIsNotThereIsANoOp() async throws {
        let (store, service) = await makeStore(threePartsSnapshot())
        let target = try occurrence(store, S.condominio, S.month(2026, 10))
        let calls = service.calls

        #expect(await store.unmarkPaid(ExpenseBillDraft(occurrence: target, today: S.today), for: target))
        #expect(service.calls == calls)
        #expect(store.errorMessage == nil)
    }

    @Test func overdueCountsParts() async {
        let (store, _) = await makeStore(threePartsSnapshot(withLuz: true))
        #expect(store.overduePayables(today: S.today).count == 3)
        #expect(store.summary(for: S.month(2026, 10), today: S.today).overdueCount == 3)
    }
}
