import Foundation

enum QuickSpending {
    static func defaultExpense(options: [Expense], entries: [ExpenseEntry]) -> Expense? {
        let ids = Set(options.map(\.id))
        let lastUsed = entries
            .filter { ids.contains($0.expenseID) }
            .max { $0.spentOn < $1.spentOn }?
            .expenseID
        return options.first { $0.id == lastUsed } ?? options.first
    }

    static func ranked(options: [Expense], entries: [ExpenseEntry], today: CalendarDay) -> [Expense] {
        let lastUsed = defaultExpense(options: options, entries: entries).flatMap { first in
            entries.contains { $0.expenseID == first.id } ? first.id : nil
        }
        let since = today.adding(days: -ExpenseConstants.quickSpendingFrequencyDays)
        let recentCounts = Dictionary(grouping: entries.filter { $0.spentOn >= since }, by: \.expenseID).mapValues(\.count)

        return options.sorted { left, right in
            if (left.id == lastUsed) != (right.id == lastUsed) { return left.id == lastUsed }
            let leftCount = recentCounts[left.id] ?? 0
            let rightCount = recentCounts[right.id] ?? 0
            if leftCount != rightCount { return leftCount > rightCount }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    static func matching(_ options: [Expense], query: String) -> [Expense] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return options }
        return options.filter { matches($0.name, query: trimmed) }
    }

    static func matches(_ name: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive], locale: IncomeFormat.locale) != nil
    }

    static func amount(from value: Double) -> Decimal {
        var source = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }

    static func subtitle(spent: Decimal, month: YearMonth) -> String {
        "\(IncomeFormat.currency(spent)) em \(IncomeFormat.monthName(month))"
    }
}
