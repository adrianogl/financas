import Foundation
import Observation

@MainActor
@Observable
final class SuggestionStore {
    private(set) var snapshot: SuggestionSnapshot = .empty
    private(set) var loadState: IncomeLoadState = .idle
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let service: SuggestionService
    private let expenses: ExpenseStore
    private let device: @MainActor () -> SuggestionDevice
    private let now: () -> Date
    private var generation = 0

    init(
        service: SuggestionService,
        expenses: ExpenseStore,
        device: @escaping @MainActor () -> SuggestionDevice = { DeviceIdentity.current() },
        now: @escaping () -> Date = { .now }
    ) {
        self.service = service
        self.expenses = expenses
        self.device = device
        self.now = now
    }

    var pending: [SpendingSuggestion] {
        suggestions(with: .pending)
    }

    var dismissed: [SpendingSuggestion] {
        suggestions(with: .dismissed)
    }

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        let started = generation
        do {
            let loaded = try await service.load(since: historyStart)
            guard started == generation else { return }
            snapshot = loaded
            loadState = .loaded
        } catch {
            guard started == generation else { return }
            loadState = .failed(error == .network ? error.message : SuggestionConstants.loadFailedMessage)
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
            guard let loaded = try? await service.load(since: historyStart), started == generation else { return false }
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

    func options(for suggestion: SpendingSuggestion, today: CalendarDay) -> [Expense] {
        let month = suggestion.spentOn.yearMonth
        let available = expenses.spendings(in: month, today: today).map(\.expense)
        return QuickSpending.ranked(options: available, entries: expenses.snapshot.entries, today: today)
    }

    func suggestedExpense(for suggestion: SpendingSuggestion, options: [Expense]) -> Expense? {
        SuggestedCategory.expense(for: suggestion.merchantKey, rules: snapshot.rules, options: options, entries: expenses.snapshot.entries)
    }

    func autoLaunchExpense(for suggestion: SpendingSuggestion, options: [Expense]) -> Expense? {
        SuggestedCategory.autoLaunchExpense(for: suggestion.merchantKey, rules: snapshot.rules, options: options)
    }

    func confirmedCount(for suggestion: SpendingSuggestion, expense: Expense) -> Int {
        SuggestedCategory.confirmedCount(merchantKey: suggestion.merchantKey, expenseID: expense.id, suggestions: snapshot.suggestions)
    }

    func autoLaunches(_ suggestion: SpendingSuggestion) -> Bool {
        snapshot.rules.first { $0.merchantKey == suggestion.merchantKey }?.autoLaunch ?? false
    }

    func report(_ purchase: SuggestionPurchase) async -> SuggestionReport? {
        let started = generation
        do {
            let report = try await service.report(purchase, merchantKey: MerchantKey.make(purchase.merchant), device: device())
            guard started == generation else { return nil }
            upsert(report.suggestion)
            return report
        } catch {
            guard started == generation else { return nil }
            errorMessage = error.message
            return nil
        }
    }

    func confirm(_ suggestion: SpendingSuggestion, in expense: Expense, autoLaunch: Bool? = nil) async -> SuggestionConfirmation? {
        let started = generation
        do {
            let result = try await service.confirm(id: suggestion.id, expenseID: expense.id, spentOn: suggestion.spentOn, autoLaunch: autoLaunch)
            guard started == generation else { return nil }
            upsert(result.suggestion)
            if let entry = result.suggestion.entry {
                expenses.merge(entry)
            }
            if !result.already {
                remember(merchantKey: suggestion.merchantKey, expenseID: expense.id, autoLaunch: autoLaunch)
            }
            return result
        } catch {
            guard started == generation else { return nil }
            errorMessage = error.message
            return nil
        }
    }

    func reopen(_ suggestion: SpendingSuggestion) async -> Bool {
        let started = generation
        do {
            let reopened = try await service.reopen(id: suggestion.id)
            guard started == generation else { return false }
            if let entryID = current(suggestion).entryID {
                expenses.forget(entryID: entryID)
            }
            upsert(reopened)
            return true
        } catch {
            guard started == generation else { return false }
            errorMessage = error.message
            return false
        }
    }

    func move(_ suggestion: SpendingSuggestion, to expense: Expense) async -> Bool {
        await perform { [service] () async throws(IncomeError) in
            try await service.move(id: suggestion.id, expenseID: expense.id)
        } onSuccess: { moved in
            self.upsert(moved)
            if let entry = moved.entry {
                self.expenses.merge(entry)
            }
            self.remember(merchantKey: moved.merchantKey, expenseID: expense.id, autoLaunch: nil)
        }
    }

    func dismiss(_ suggestion: SpendingSuggestion) async -> Bool {
        await perform { [service] () async throws(IncomeError) in
            try await service.dismiss(id: suggestion.id)
        } onSuccess: { _ in
            var dismissed = self.current(suggestion)
            guard dismissed.status == .pending else { return }
            dismissed.status = .dismissed
            self.upsert(dismissed)
        }
    }

    private var historyStart: Date {
        Calendar.current.date(byAdding: .day, value: -SuggestionConstants.historyDays, to: now()) ?? now()
    }

    private func suggestions(with status: SpendingSuggestionStatus) -> [SpendingSuggestion] {
        snapshot.suggestions.filter { $0.status == status }.sorted { $0.occurredAt > $1.occurredAt }
    }

    private func current(_ suggestion: SpendingSuggestion) -> SpendingSuggestion {
        snapshot.suggestions.first { $0.id == suggestion.id } ?? suggestion
    }

    private func upsert(_ suggestion: SpendingSuggestion) {
        if let index = snapshot.suggestions.firstIndex(where: { $0.id == suggestion.id }) {
            snapshot.suggestions[index] = suggestion
        } else {
            snapshot.suggestions.append(suggestion)
        }
    }

    private func remember(merchantKey: String, expenseID: UUID, autoLaunch: Bool?) {
        if let index = snapshot.rules.firstIndex(where: { $0.merchantKey == merchantKey }) {
            snapshot.rules[index].expenseID = expenseID
            if let autoLaunch {
                snapshot.rules[index].autoLaunch = autoLaunch
            }
        } else {
            snapshot.rules.append(MerchantSpendingRule(id: UUID(), merchantKey: merchantKey, expenseID: expenseID, autoLaunch: autoLaunch ?? false))
        }
    }

    private func perform<Value>(
        _ operation: () async throws(IncomeError) -> Value,
        onSuccess: (Value) -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let started = generation
        do {
            let value = try await operation()
            guard started == generation else { return false }
            onSuccess(value)
            return true
        } catch {
            guard started == generation else { return false }
            errorMessage = error.message
            return false
        }
    }
}
