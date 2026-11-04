import Foundation

@MainActor
enum SpendingCatalog {
    static func loaded(_ store: ExpenseStore) async throws(SpendingIntentError) {
        if store.loadState != .loaded {
            await store.load()
        }
        guard store.loadState == .loaded else { throw .unavailable }
    }

    static func entities(store: ExpenseStore, today: CalendarDay = CalendarDay(date: .now)) async throws(SpendingIntentError) -> [SpendingEntity] {
        try await loaded(store)
        let months = store.spendings(in: today.yearMonth, today: today)
        guard !months.isEmpty else { throw .noSpendings }
        let spent = Dictionary(uniqueKeysWithValues: months.map { ($0.expense.id, $0.spent) })
        return QuickSpending.ranked(options: months.map(\.expense), entries: store.snapshot.entries, today: today).map {
            SpendingEntity(id: $0.id, name: $0.name, monthTotal: QuickSpending.subtitle(spent: spent[$0.id] ?? 0, month: today.yearMonth))
        }
    }

    static func monthSpent(of expense: Expense, store: ExpenseStore, today: CalendarDay) -> Decimal {
        store.spendings(in: today.yearMonth, today: today).first { $0.expense.id == expense.id }?.spent ?? 0
    }
}
