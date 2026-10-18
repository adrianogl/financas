import Foundation
import Observation

@MainActor
@Observable
final class ExpenseStore {
    private(set) var snapshot: ExpenseSnapshot = .empty
    private(set) var loadState: IncomeLoadState = .idle
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let service: ExpenseService
    private var generation = 0

    init(service: ExpenseService) {
        self.service = service
    }

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        let started = generation
        do {
            let loaded = try await service.load()
            guard started == generation else { return }
            snapshot = loaded
            loadState = .loaded
        } catch {
            guard started == generation else { return }
            loadState = .failed(error == .network ? error.message : ExpenseConstants.loadFailedMessage)
        }
    }

    @discardableResult
    func refresh() async -> Bool {
        switch loadState {
        case .idle, .failed:
            await load()
            return loadState == .loaded
        case .loading:
            return false
        case .loaded:
            let started = generation
            guard let loaded = try? await service.load(), started == generation else { return false }
            snapshot = loaded
            return true
        }
    }

    func reset() {
        generation += 1
        snapshot = .empty
        loadState = .idle
        errorMessage = nil
    }

    func occurrences(in month: YearMonth, today: CalendarDay) -> [ExpenseOccurrence] {
        let own = ExpenseSchedule.occurrences(in: month, snapshot: snapshot, today: today)
        guard month == today.yearMonth else { return own }
        return ExpenseSchedule.carried(into: month, snapshot: snapshot, today: today) + own
    }

    func overdueOccurrences(today: CalendarDay) -> [ExpenseOccurrence] {
        occurrences(in: today.yearMonth, today: today)
            .filter { $0.status == .overdue }
            .sorted { lhs, rhs in
                lhs.dueDate != rhs.dueDate
                    ? lhs.dueDate < rhs.dueDate
                    : lhs.expense.name.localizedStandardCompare(rhs.expense.name) == .orderedAscending
            }
    }

    func overdueTotal(today: CalendarDay) -> Decimal {
        overdueOccurrences(today: today).map(\.remaining).reduce(0, +)
    }

    func summary(for month: YearMonth, today: CalendarDay) -> ExpenseMonthSummary {
        ExpenseSchedule.summary(for: month, snapshot: snapshot, today: today)
    }

    func spendings(in month: YearMonth, today: CalendarDay) -> [SpendingMonth] {
        SpendingSchedule.months(in: month, snapshot: snapshot, today: today)
    }

    func spendingHistory(of expense: Expense, through month: YearMonth, today: CalendarDay) -> [SpendingMonth] {
        SpendingSchedule.history(of: expense, through: month, snapshot: snapshot, today: today)
    }

    func dueItems(today: CalendarDay) -> [DueItem]? {
        guard loadState == .loaded else { return nil }
        let previous = ExpenseSchedule.occurrences(in: today.yearMonth.previous, snapshot: snapshot, today: today)
        let upcoming = ExpenseSchedule.occurrences(in: today.yearMonth.next, snapshot: snapshot, today: today)
        var seen = Set<String>()
        return (previous + occurrences(in: today.yearMonth, today: today) + upcoming)
            .filter { $0.status != .paid && seen.insert($0.id).inserted }
            .map { DueItem(expense: $0, today: today) }
    }

    func currentTerm(for expense: Expense, today: CalendarDay) -> ExpenseTerm? {
        ExpenseSchedule.term(for: expense, in: today.yearMonth, snapshot: snapshot)
    }

    func currentEstimate(for expense: Expense, today: CalendarDay) -> ExpenseEstimate? {
        ExpenseSchedule.estimate(for: expense, in: today.yearMonth, snapshot: snapshot)
    }

    func activeExpenses(today: CalendarDay) -> [Expense] {
        sortedExpenses.filter { expense in expense.endMonth.map { $0 >= today.yearMonth } ?? true }
    }

    func endedExpenses(today: CalendarDay) -> [Expense] {
        sortedExpenses.filter { expense in expense.endMonth.map { $0 < today.yearMonth } ?? false }
    }

    func save(_ draft: ExpenseDraft, today: CalendarDay) async -> Bool {
        if let message = draft.validationMessage {
            errorMessage = message
            return false
        }
        let (expense, newTerm) = draft.build(today: today)
        let term = newTerm.map(reusingExistingID)
        let changes = draft.buildParts(today: today)
        let partTerms = changes.terms.map(reusingExistingID)
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(expense, term: term, parts: changes.parts, partTerms: partTerms)
        } onSuccess: {
            self.upsert(expense)
            if let term {
                self.snapshot.terms.removeAll { $0.expenseID == term.expenseID && $0.validFrom == term.validFrom }
                self.snapshot.terms.append(term)
            }
            for part in changes.parts {
                self.snapshot.parts.removeAll { $0.id == part.id }
                self.snapshot.parts.append(part)
            }
            for partTerm in partTerms {
                self.snapshot.partTerms.removeAll { $0.partID == partTerm.partID && $0.validFrom == partTerm.validFrom }
                self.snapshot.partTerms.append(partTerm)
            }
        }
    }

    func end(_ expense: Expense, in month: YearMonth) async -> Bool {
        var ended = expense
        ended.endMonth = max(month, expense.startMonth)
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(ended, term: nil, parts: [], partTerms: [])
        } onSuccess: {
            self.upsert(ended)
        }
    }

    func delete(_ expense: Expense) async -> Bool {
        await perform { [service] () async throws(IncomeError) in
            try await service.delete(expenseID: expense.id)
        } onSuccess: {
            self.snapshot.expenses.removeAll { $0.id == expense.id }
            self.snapshot.terms.removeAll { $0.expenseID == expense.id }
            self.snapshot.bills.removeAll { $0.expenseID == expense.id }
            let partIDs = Set(self.snapshot.parts.filter { $0.expenseID == expense.id }.map(\.id))
            self.snapshot.parts.removeAll { $0.expenseID == expense.id }
            self.snapshot.partTerms.removeAll { partIDs.contains($0.partID) }
            self.snapshot.partBills.removeAll { partIDs.contains($0.partID) }
            self.snapshot.entries.removeAll { $0.expenseID == expense.id }
        }
    }

    func saveBill(_ draft: ExpenseBillDraft, for occurrence: ExpenseOccurrence) async -> Bool {
        guard occurrence.parts.isEmpty else { return await persist(draft.partBillsSaved(for: occurrence)) }
        return await persist(draft.billSaved(for: occurrence), replacing: occurrence)
    }

    func removeBill(_ draft: ExpenseBillDraft, for occurrence: ExpenseOccurrence) async -> Bool {
        guard occurrence.parts.isEmpty else { return await persist(draft.partBillsRemoved(for: occurrence)) }
        return await persist(draft.billRemoved(for: occurrence), replacing: occurrence)
    }

    func markPaid(_ draft: ExpenseBillDraft, for occurrence: ExpenseOccurrence) async -> Bool {
        guard occurrence.parts.isEmpty else { return await persist(draft.partPaymentsSaved(for: occurrence)) }
        return await persist(draft.paymentSaved(for: occurrence), replacing: occurrence)
    }

    func unmarkPaid(_ draft: ExpenseBillDraft, for occurrence: ExpenseOccurrence) async -> Bool {
        guard occurrence.parts.isEmpty else { return await persist(draft.partPaymentsRemoved(for: occurrence)) }
        return await persist(draft.paymentRemoved(for: occurrence), replacing: occurrence)
    }

    func saveEntry(_ draft: ExpenseEntryDraft) async -> Bool {
        if let message = draft.validationMessage {
            errorMessage = message
            return false
        }
        let entry = draft.build()
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(entry)
        } onSuccess: {
            self.snapshot.entries.removeAll { $0.id == entry.id }
            self.snapshot.entries.append(entry)
        }
    }

    func deleteEntry(_ entry: ExpenseEntry) async -> Bool {
        await perform { [service] () async throws(IncomeError) in
            try await service.deleteEntry(id: entry.id)
        } onSuccess: {
            self.snapshot.entries.removeAll { $0.id == entry.id }
        }
    }

    private var sortedExpenses: [Expense] {
        snapshot.expenses.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func persist(_ bill: ExpenseBill?, replacing occurrence: ExpenseOccurrence) async -> Bool {
        guard let bill else {
            guard let existing = occurrence.bill else { return false }
            return await perform { [service] () async throws(IncomeError) in
                try await service.deleteBill(id: existing.id)
            } onSuccess: {
                self.snapshot.bills.removeAll { $0.id == existing.id }
            }
        }
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(bill)
        } onSuccess: {
            self.snapshot.bills.removeAll { $0.id == bill.id }
            self.snapshot.bills.append(bill)
        }
    }

    private func persist(_ partBills: [ExpensePartBill]) async -> Bool {
        let kept = partBills.filter { !$0.isEmpty }
        let knownIDs = Set(snapshot.partBills.map(\.id))
        let removedIDs = partBills.filter { $0.isEmpty && knownIDs.contains($0.id) }.map(\.id)
        guard !kept.isEmpty || !removedIDs.isEmpty else { return false }
        return await perform { [service] () async throws(IncomeError) in
            if !kept.isEmpty {
                try await service.save(kept)
            }
            if !removedIDs.isEmpty {
                try await service.deletePartBills(ids: removedIDs)
            }
        } onSuccess: {
            let touched = Set(partBills.map(\.id))
            self.snapshot.partBills.removeAll { touched.contains($0.id) }
            self.snapshot.partBills.append(contentsOf: kept)
        }
    }

    private func reusingExistingID(_ term: ExpenseTerm) -> ExpenseTerm {
        guard let existing = snapshot.terms.first(where: { $0.expenseID == term.expenseID && $0.validFrom == term.validFrom }) else {
            return term
        }
        return ExpenseTerm(
            id: existing.id,
            expenseID: term.expenseID,
            validFrom: term.validFrom,
            estimatedAmount: term.estimatedAmount,
            dayOfMonth: term.dayOfMonth,
            averageFrom: term.averageFrom
        )
    }

    private func reusingExistingID(_ term: ExpensePartTerm) -> ExpensePartTerm {
        guard let existing = snapshot.partTerms.first(where: { $0.partID == term.partID && $0.validFrom == term.validFrom }) else {
            return term
        }
        return ExpensePartTerm(
            id: existing.id,
            partID: term.partID,
            validFrom: term.validFrom,
            amount: term.amount,
            isFixed: term.isFixed,
            averageFrom: term.averageFrom,
            isActive: term.isActive,
            dayOfMonth: term.dayOfMonth
        )
    }

    private func upsert(_ expense: Expense) {
        if let index = snapshot.expenses.firstIndex(where: { $0.id == expense.id }) {
            snapshot.expenses[index] = expense
        } else {
            snapshot.expenses.append(expense)
        }
    }

    private func perform(
        _ operation: () async throws(IncomeError) -> Void,
        onSuccess: () -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let started = generation

        do {
            try await operation()
            guard started == generation else { return false }
            onSuccess()
            return true
        } catch {
            guard started == generation else { return false }
            errorMessage = error.message
            return false
        }
    }
}
