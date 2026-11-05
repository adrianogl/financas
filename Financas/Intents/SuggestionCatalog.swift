import Foundation

@MainActor
enum SuggestionCatalog {
    static func prepared(expenses: ExpenseStore, suggestions: SuggestionStore) async throws(SpendingIntentError) {
        try await SpendingCatalog.loaded(expenses)
        await suggestions.refresh()
    }

    static func suggestion(_ id: String, in store: SuggestionStore) throws(SpendingIntentError) -> SpendingSuggestion {
        guard store.loadState == .loaded else { throw .unavailable }
        guard let uuid = UUID(uuidString: id), let suggestion = store.snapshot.suggestions.first(where: { $0.id == uuid }) else {
            throw .suggestionGone
        }
        return suggestion
    }

    static func expense(_ id: String, in store: ExpenseStore) throws(SpendingIntentError) -> Expense {
        guard let uuid = UUID(uuidString: id),
              let expense = store.snapshot.expenses.first(where: { $0.id == uuid && $0.kind == .spending }) else {
            throw .unavailable
        }
        return expense
    }

    static func content(for suggestion: SpendingSuggestion, store: SuggestionStore, options: [Expense]) -> SuggestionSnippetContent {
        let suggested = store.suggestedExpense(for: suggestion, options: options)
        return SuggestionSnippetContent(
            suggestionID: suggestion.id,
            amount: IncomeFormat.currency(suggestion.amount),
            merchant: suggestion.merchant,
            detail: detail(of: suggestion),
            suggested: suggested.map { SuggestionChoice(id: $0.id, name: $0.name, hint: hint(count: store.confirmedCount(for: suggestion, expense: $0))) },
            alternatives: SuggestedCategory.alternatives(to: suggested, ranked: options).map { SuggestionChoice(id: $0.id, name: $0.name, hint: nil) }
        )
    }

    static func launchedTitle(_ suggestion: SpendingSuggestion, in expense: Expense) -> String {
        "\(IncomeFormat.currency(suggestion.amount)) lançado em \(expense.name)"
    }

    static func monthTotal(of expense: Expense, expenses: ExpenseStore, today: CalendarDay) -> String {
        "\(expense.name) em \(IncomeFormat.monthName(today.yearMonth)): \(IncomeFormat.currency(SpendingCatalog.monthSpent(of: expense, store: expenses, today: today)))"
    }

    static func detail(of suggestion: SpendingSuggestion) -> String {
        let time = suggestion.occurredAt.formatted(date: .abbreviated, time: .shortened)
        return suggestion.card.isEmpty ? time : "\(suggestion.card) · \(time)"
    }

    private static func hint(count: Int) -> String? {
        switch count {
        case 0: nil
        case 1: "Usado na última compra aqui"
        default: "Usado nas últimas \(count) compras aqui"
        }
    }
}
