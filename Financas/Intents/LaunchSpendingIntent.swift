import AppIntents
import SwiftUI

struct LaunchSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Lançar gasto"
    static let description = IntentDescription("Lança um gasto do mês, como padaria ou farmácia, sem abrir o app.")
    static let openAppWhenRun = false

    @Parameter(title: "Valor", requestValueDialog: "Finanças · Quanto foi?")
    var amount: Double

    @Parameter(title: "Gasto do mês", requestValueDialog: "Finanças · Onde foi o gasto?")
    var spending: SpendingEntity

    @Dependency private var store: ExpenseStore

    static var parameterSummary: some ParameterSummary {
        Summary("Lançar \(\.$amount) em \(\.$spending)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let today = CalendarDay(date: .now)
        let value = QuickSpending.amount(from: amount)
        guard value > 0 else { throw SpendingIntentError.invalidAmount }
        try await SpendingCatalog.loaded(store)
        guard let expense = store.snapshot.expenses.first(where: { $0.id == spending.id }) else {
            throw SpendingIntentError.unavailable
        }

        var draft = ExpenseEntryDraft(expense: expense, month: today.yearMonth, today: today)
        draft.amount = value
        guard await store.saveEntry(draft) else {
            throw SpendingIntentError.saveFailed(store.errorMessage ?? "")
        }

        let title = "\(IncomeFormat.currency(value)) lançado em \(expense.name)"
        let total = "\(expense.name) em \(IncomeFormat.monthName(today.yearMonth)): \(IncomeFormat.currency(SpendingCatalog.monthSpent(of: expense, store: store, today: today)))"
        return .result(
            dialog: "\(title)",
            view: SpendingLaunchedSnippet(title: title, total: total, entryID: draft.entryID)
        )
    }
}
