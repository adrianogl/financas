import AppIntents
import SwiftUI

struct ConfirmSuggestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Lançar compra sugerida"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Compra")
    var suggestionID: String

    @Parameter(title: "Gasto do mês")
    var expenseID: String

    @Dependency private var expenses: ExpenseStore
    @Dependency private var suggestions: SuggestionStore

    init() {}

    init(suggestionID: UUID, expenseID: UUID) {
        self.suggestionID = suggestionID.uuidString
        self.expenseID = expenseID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        try await SuggestionCatalog.prepared(expenses: expenses, suggestions: suggestions)
        let suggestion = try SuggestionCatalog.suggestion(suggestionID, in: suggestions)
        let chosen = try SuggestionCatalog.expense(expenseID, in: expenses)
        guard let result = await suggestions.confirm(suggestion, in: chosen) else {
            throw SpendingIntentError.saveFailed(suggestions.errorMessage ?? "")
        }

        let today = CalendarDay(date: .now)
        let launchedID = result.suggestion.expenseID ?? chosen.id
        let launchedIn = expenses.snapshot.expenses.first { $0.id == launchedID } ?? chosen

        if result.already {
            guard launchedIn.id != chosen.id else {
                let title = "Já estava lançado em \(launchedIn.name)"
                return .result(
                    dialog: "\(title)",
                    view: SuggestionResultSnippet(tone: .done, title: title, detail: "Confirmado em outro aparelho. Não lancei de novo.", action: nil)
                )
            }
            let title = "Já lançado em \(launchedIn.name)"
            return .result(
                dialog: "\(title)",
                view: SuggestionResultSnippet(
                    tone: .attention,
                    title: title,
                    detail: "Em outro aparelho você escolheu \(launchedIn.name). Quer mover para \(chosen.name)?",
                    action: .move(suggestionID: suggestion.id, expenseID: chosen.id, expenseName: chosen.name)
                )
            )
        }

        let title = SuggestionCatalog.launchedTitle(result.suggestion, in: chosen)
        return .result(
            dialog: "\(title)",
            view: SuggestionResultSnippet(
                tone: .done,
                title: title,
                detail: SuggestionCatalog.monthTotal(of: chosen, expenses: expenses, today: today),
                action: .undo(suggestionID: suggestion.id)
            )
        )
    }
}
