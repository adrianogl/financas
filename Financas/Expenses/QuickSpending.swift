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
}
