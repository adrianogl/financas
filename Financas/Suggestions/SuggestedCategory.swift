import Foundation

enum SuggestedCategory {
    static func expense(
        for merchantKey: String,
        rules: [MerchantSpendingRule],
        options: [Expense],
        entries: [ExpenseEntry]
    ) -> Expense? {
        if let rule = rules.first(where: { $0.merchantKey == merchantKey }),
           let match = options.first(where: { $0.id == rule.expenseID }) {
            return match
        }
        return QuickSpending.defaultExpense(options: options, entries: entries)
    }

    static func autoLaunchExpense(for merchantKey: String, rules: [MerchantSpendingRule], options: [Expense]) -> Expense? {
        guard let rule = rules.first(where: { $0.merchantKey == merchantKey }), rule.autoLaunch else { return nil }
        return options.first { $0.id == rule.expenseID }
    }

    static func alternatives(to suggested: Expense?, ranked: [Expense]) -> [Expense] {
        Array(ranked.filter { $0.id != suggested?.id }.prefix(SuggestionConstants.alternativesCount))
    }

    static func confirmedCount(merchantKey: String, expenseID: UUID, suggestions: [SpendingSuggestion]) -> Int {
        suggestions.filter { $0.status == .confirmed && $0.merchantKey == merchantKey && $0.expenseID == expenseID }.count
    }
}
