import Foundation
import Observation

@MainActor
@Observable
final class IncomeStore {
    private(set) var snapshot: IncomeSnapshot = .empty
    private(set) var loadState: IncomeLoadState = .idle
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var isSavingSettings = false
    private(set) var settingsErrorMessage: String?
    var selectedMonth: YearMonth
    var today: CalendarDay

    private let service: IncomeService
    private var savedSettings = AccountSettings.standard
    private var settingsSave: Task<Bool, Never>?
    private let currentDay: () -> CalendarDay
    private var generation = 0

    init(service: IncomeService, today: @escaping () -> CalendarDay = { CalendarDay(date: .now) }) {
        self.service = service
        currentDay = today
        let day = today()
        self.today = day
        selectedMonth = day.yearMonth
    }

    func load() async {
        guard loadState != .loading else { return }
        moveToday()
        loadState = .loading
        let started = generation
        do {
            let loaded = try await service.load()
            guard started == generation else { return }
            snapshot = loaded
            savedSettings = loaded.settings
            loadState = .loaded
        } catch {
            guard started == generation else { return }
            loadState = .failed(error.loadMessage)
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
            moveToday()
            let started = generation
            guard let loaded = try? await service.load(), started == generation else { return false }
            snapshot = loaded
            savedSettings = loaded.settings
            return true
        }
    }

    func reset() {
        generation += 1
        snapshot = .empty
        savedSettings = .standard
        settingsSave = nil
        loadState = .idle
        errorMessage = nil
        settingsErrorMessage = nil
        today = currentDay()
        selectedMonth = today.yearMonth
    }

    func moveToday() {
        let previous = today
        today = currentDay()
        if selectedMonth == previous.yearMonth {
            selectedMonth = today.yearMonth
        }
    }

    func showCurrentMonth() {
        selectedMonth = today.yearMonth
    }

    func occurrences(in month: YearMonth) -> [IncomeOccurrence] {
        let own = IncomeSchedule.occurrences(in: month, snapshot: snapshot, today: today)
        guard month == today.yearMonth else { return own }
        return IncomeSchedule.carried(into: month, snapshot: snapshot, today: today) + own
    }

    var overdueOccurrences: [IncomeOccurrence] {
        occurrences(in: today.yearMonth)
            .filter { $0.status == .overdue }
            .sorted { lhs, rhs in
                lhs.dueDate != rhs.dueDate
                    ? lhs.dueDate < rhs.dueDate
                    : lhs.income.name.localizedStandardCompare(rhs.income.name) == .orderedAscending
            }
    }

    var overdueTotal: Decimal {
        overdueOccurrences.map(\.expectedAmount).reduce(0, +)
    }

    var dueItems: [DueItem]? {
        guard loadState == .loaded else { return nil }
        let previous = IncomeSchedule.occurrences(in: today.yearMonth.previous, snapshot: snapshot, today: today)
        let upcoming = IncomeSchedule.occurrences(in: today.yearMonth.next, snapshot: snapshot, today: today)
        var seen = Set<String>()
        return (previous + occurrences(in: today.yearMonth) + upcoming)
            .filter { $0.status != .received && seen.insert($0.id).inserted }
            .map(DueItem.init(occurrence:))
    }

    func summary(for month: YearMonth) -> MonthSummary {
        IncomeSchedule.summary(for: month, snapshot: snapshot, today: today)
    }

    func currentAmount(for income: Income) -> Decimal? {
        snapshot.amounts
            .filter { $0.incomeID == income.id && $0.validFrom <= today.yearMonth }
            .max { $0.validFrom < $1.validFrom }?
            .amount
    }

    var activeRecurring: [Income] {
        recurring.filter { income in income.endMonth.map { $0 >= today.yearMonth } ?? true }
    }

    var endedRecurring: [Income] {
        recurring.filter { income in income.endMonth.map { $0 < today.yearMonth } ?? false }
    }

    func save(_ draft: IncomeDraft) async -> Bool {
        if let message = draft.validationMessage {
            errorMessage = message
            return false
        }
        let (income, newAmount) = draft.build()
        let amount = newAmount.map(reusingExistingID)
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(income, amount: amount)
        } onSuccess: {
            self.upsert(income)
            if let amount {
                self.snapshot.amounts.removeAll { $0.incomeID == amount.incomeID && $0.validFrom == amount.validFrom }
                self.snapshot.amounts.append(amount)
            }
        }
    }

    func end(_ income: Income, in month: YearMonth) async -> Bool {
        var ended = income
        ended.endMonth = max(month, income.startMonth ?? month)
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(ended, amount: nil)
        } onSuccess: {
            self.upsert(ended)
        }
    }

    func delete(_ income: Income) async -> Bool {
        await perform { [service] () async throws(IncomeError) in
            try await service.delete(incomeID: income.id)
        } onSuccess: {
            self.snapshot.incomes.removeAll { $0.id == income.id }
            self.snapshot.amounts.removeAll { $0.incomeID == income.id }
            self.snapshot.receipts.removeAll { $0.incomeID == income.id }
        }
    }

    func markReceived(_ occurrence: IncomeOccurrence, with draft: ReceiptDraft) async -> Bool {
        let receipt = draft.receipt(for: occurrence)
        return await perform { [service] () async throws(IncomeError) in
            try await service.save(receipt)
        } onSuccess: {
            self.snapshot.receipts.removeAll { $0.incomeID == receipt.incomeID && $0.month == receipt.month }
            self.snapshot.receipts.append(receipt)
        }
    }

    func unmarkReceived(_ occurrence: IncomeOccurrence) async -> Bool {
        guard let receipt = occurrence.receipt else { return false }
        return await perform { [service] () async throws(IncomeError) in
            try await service.deleteReceipt(id: receipt.id)
        } onSuccess: {
            self.snapshot.receipts.removeAll { $0.id == receipt.id }
        }
    }

    var settings: AccountSettings {
        snapshot.settings
    }

    @discardableResult
    func updateSettings(_ new: AccountSettings) -> Task<Bool, Never> {
        snapshot.settings = new
        settingsErrorMessage = nil
        let previous = settingsSave
        let started = generation
        let save = Task {
            _ = await previous?.value
            return await self.persistSettings(started: started)
        }
        settingsSave = save
        return save
    }

    private func persistSettings(started: Int) async -> Bool {
        guard started == generation else { return false }
        let target = snapshot.settings
        let saved = savedSettings
        guard target != saved else { return true }
        isSavingSettings = true
        defer { isSavingSettings = false }

        do {
            try await service.saveSettings(target, previous: saved)
            guard started == generation else { return false }
            savedSettings = target
            return true
        } catch {
            guard started == generation else { return false }
            snapshot.settings = saved
            settingsErrorMessage = error.message
            return false
        }
    }

    private var recurring: [Income] {
        snapshot.incomes
            .filter { $0.kind != .oneOff }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func reusingExistingID(_ amount: IncomeAmount) -> IncomeAmount {
        guard let existing = snapshot.amounts.first(where: { $0.incomeID == amount.incomeID && $0.validFrom == amount.validFrom }) else {
            return amount
        }
        return IncomeAmount(id: existing.id, incomeID: amount.incomeID, amount: amount.amount, validFrom: amount.validFrom)
    }

    private func upsert(_ income: Income) {
        if let index = snapshot.incomes.firstIndex(where: { $0.id == income.id }) {
            snapshot.incomes[index] = income
        } else {
            snapshot.incomes.append(income)
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
