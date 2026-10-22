import Foundation
import Observation

@MainActor
@Observable
final class CardStore {
    private(set) var snapshot: CardSnapshot = .empty
    private(set) var loadState: IncomeLoadState = .idle
    private(set) var errorMessage: String?
    var filter: CardFilter = .all
    var today: CalendarDay

    private let service: CardService
    private var generation = 0

    init(service: CardService, today: CalendarDay = CalendarDay(date: .now)) {
        self.service = service
        self.today = today
    }

    var accounts: [CardAccount] {
        snapshot.accounts.sorted { $0.nickname.localizedStandardCompare($1.nickname) == .orderedAscending }
    }

    var plans: [InstallmentPlan] {
        InstallmentPlans.plans(from: snapshot.transactions, today: today)
            .filter { $0.lastMonth >= today.yearMonth && matches($0.cardAccountID) }
    }

    var fixedCharges: [FixedCharge] {
        FixedCharges.charges(from: snapshot.transactions, recurrences: snapshot.recurrences, today: today)
            .filter { matches($0.recurrence.cardAccountID) }
    }

    var candidates: [RecurrenceCandidate] {
        RecurrenceDetector.candidates(from: snapshot.transactions, decisions: snapshot.recurrences, today: today)
            .filter { matches($0.cardAccountID) }
    }

    var months: [CommitmentMonth] {
        CardCommitment.months(plans: plans, fixed: fixedCharges, from: today.yearMonth.next, count: CardConstants.commitmentMonthCount)
    }

    var ending: [InstallmentPlan] {
        CardCommitment.ending(plans, today: today)
    }

    var reviewCount: Int {
        candidates.count
    }

    var oldestSync: Date? {
        snapshot.connections.compactMap(\.lastSyncedAt).min()
    }

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        let started = generation
        do {
            let loaded = try await service.load(since: historyStart)
            guard started == generation else { return }
            apply(loaded)
            loadState = .loaded
        } catch {
            guard started == generation else { return }
            loadState = .failed(error == .network ? error.message : CardConstants.loadFailedMessage)
        }
    }

    @discardableResult
    func refresh() async -> Bool {
        guard loadState != .loading else { return false }
        errorMessage = nil
        let started = generation
        var synced = true
        do {
            try await service.sync()
        } catch {
            synced = false
        }
        guard started == generation else { return false }
        if loadState == .loaded {
            guard let loaded = try? await service.load(since: historyStart), started == generation else {
                if started == generation { errorMessage = CardConstants.syncFailedMessage }
                return false
            }
            apply(loaded)
        } else {
            await load()
            guard loadState == .loaded else { return false }
        }
        if !synced { errorMessage = CardConstants.syncFailedMessage }
        return synced
    }

    func reset() {
        generation += 1
        snapshot = .empty
        loadState = .idle
        errorMessage = nil
        filter = .all
    }

    @discardableResult
    func decide(_ candidate: RecurrenceCandidate, isFixed: Bool) async -> Bool {
        let existing = snapshot.recurrences.first {
            $0.cardAccountID == candidate.cardAccountID && $0.merchantKey == candidate.merchantKey
        }
        let decision = CardRecurrence(
            id: existing?.id ?? UUID(),
            cardAccountID: candidate.cardAccountID,
            merchantKey: candidate.merchantKey,
            status: isFixed ? .confirmed : .dismissed,
            endedOn: nil
        )
        return await save(decision)
    }

    @discardableResult
    func end(_ charge: FixedCharge) async -> Bool {
        var ended = charge.recurrence
        ended.status = .ended
        ended.endedOn = today
        return await save(ended)
    }

    @discardableResult
    func rename(_ account: CardAccount, to nickname: String) async -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let previous = snapshot
        update(account.id) { $0.nickname = trimmed }
        return await perform(restoring: previous) { [service] () async throws(IncomeError) in
            try await service.rename(accountID: account.id, nickname: trimmed)
        }
    }

    func connectToken(for connection: CardConnection?) async -> String? {
        errorMessage = nil
        let started = generation
        do {
            let token = try await service.connectToken(itemID: connection?.itemID)
            return started == generation ? token : nil
        } catch {
            if started == generation { errorMessage = error.message }
            return nil
        }
    }

    @discardableResult
    func register(itemID: String) async -> Bool {
        await mutateAndReload { [service] () async throws(IncomeError) in
            try await service.register(itemID: itemID)
        }
    }

    @discardableResult
    func remove(_ connection: CardConnection) async -> Bool {
        await mutateAndReload { [service] () async throws(IncomeError) in
            try await service.remove(connectionID: connection.id)
        }
    }

    private var historyStart: CalendarDay {
        var month = today.yearMonth
        for _ in 0..<CardConstants.loadHistoryMonths {
            month = month.previous
        }
        return month.day(1)
    }

    private func matches(_ accountID: UUID) -> Bool {
        switch filter {
        case .all: true
        case .account(let id): id == accountID
        }
    }

    private func apply(_ loaded: CardSnapshot) {
        snapshot = loaded
        if case .account(let id) = filter, !loaded.accounts.contains(where: { $0.id == id }) {
            filter = .all
        }
    }

    private func update(_ accountID: UUID, _ change: (inout CardAccount) -> Void) {
        guard let index = snapshot.accounts.firstIndex(where: { $0.id == accountID }) else { return }
        change(&snapshot.accounts[index])
    }

    private func save(_ recurrence: CardRecurrence) async -> Bool {
        let previous = snapshot
        snapshot.recurrences.removeAll { $0.id == recurrence.id }
        snapshot.recurrences.append(recurrence)
        return await perform(restoring: previous) { [service] () async throws(IncomeError) in
            try await service.save(recurrence)
        }
    }

    private func perform(restoring previous: CardSnapshot, _ operation: () async throws(IncomeError) -> Void) async -> Bool {
        errorMessage = nil
        let started = generation
        do {
            try await operation()
            return started == generation
        } catch {
            guard started == generation else { return false }
            snapshot = previous
            errorMessage = error.message
            return false
        }
    }

    private func mutateAndReload(_ operation: () async throws(IncomeError) -> Void) async -> Bool {
        errorMessage = nil
        let started = generation
        do {
            try await operation()
        } catch {
            if started == generation { errorMessage = error.message }
            return false
        }
        guard started == generation else { return false }
        guard let loaded = try? await service.load(since: historyStart), started == generation else {
            errorMessage = CardConstants.loadFailedMessage
            return false
        }
        apply(loaded)
        loadState = .loaded
        return true
    }
}
