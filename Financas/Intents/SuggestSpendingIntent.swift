import AppIntents
import SwiftUI

struct SuggestSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Sugerir gasto da Carteira"
    static let description = IntentDescription("Use na automação Transação da Carteira. Sugere em qual gasto do mês a compra entra e pede para confirmar.")
    static let openAppWhenRun = false

    @Parameter(title: "Valor")
    var amount: Double

    @Parameter(title: "Estabelecimento")
    var merchant: String

    @Parameter(title: "Cartão")
    var card: String?

    @Dependency private var expenses: ExpenseStore
    @Dependency private var suggestions: SuggestionStore

    static var parameterSummary: some ParameterSummary {
        Summary("Sugerir \(\.$amount) em \(\.$merchant)") {
            \.$card
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let value = QuickSpending.amount(from: amount)
        guard value > 0 else { throw SpendingIntentError.invalidAmount }
        let name = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SpendingIntentError.invalidMerchant }
        try await SuggestionCatalog.prepared(expenses: expenses, suggestions: suggestions)

        let purchase = SuggestionPurchase(
            merchant: name,
            card: card?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            amount: value,
            occurredAt: .now
        )
        guard let report = await suggestions.report(purchase) else {
            throw SpendingIntentError.saveFailed(suggestions.errorMessage ?? "")
        }
        let suggestion = report.suggestion

        guard report.created else {
            let title = "Compra já registrada"
            let detail = "\(IncomeFormat.currency(suggestion.amount)) em \(suggestion.merchant) chegou antes pelo \(suggestion.firstDeviceName). Nada novo foi criado."
            return .result(dialog: "\(title)", view: SuggestionResultSnippet(tone: .info, title: title, detail: detail, action: nil))
        }

        let today = CalendarDay(date: .now)
        let options = suggestions.options(for: suggestion, today: today)
        guard !options.isEmpty else { throw SpendingIntentError.noSpendings }

        if let expense = suggestions.autoLaunchExpense(for: suggestion, options: options),
           let result = await suggestions.confirm(suggestion, in: expense) {
            let title = SuggestionCatalog.launchedTitle(result.suggestion, in: expense)
            return .result(
                dialog: "\(title)",
                view: SuggestionResultSnippet(
                    tone: .done,
                    title: title,
                    detail: SuggestionCatalog.monthTotal(of: expense, expenses: expenses, today: today),
                    action: .undo(suggestionID: suggestion.id)
                )
            )
        }

        let content = SuggestionCatalog.content(for: suggestion, store: suggestions, options: options)
        let question = content.suggested.map { "Lançar em \($0.name)?" } ?? "Em qual gasto do mês?"
        return .result(
            dialog: "\(content.amount) em \(content.merchant). \(question)",
            view: SuggestionSnippet(content: content)
        )
    }
}
