import AppIntents

struct UndoSuggestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Desfazer compra lançada"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Compra")
    var suggestionID: String

    @Dependency private var expenses: ExpenseStore
    @Dependency private var suggestions: SuggestionStore

    init() {}

    init(suggestionID: UUID) {
        self.suggestionID = suggestionID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SuggestionCatalog.prepared(expenses: expenses, suggestions: suggestions)
        let suggestion = try SuggestionCatalog.suggestion(suggestionID, in: suggestions)
        guard await suggestions.reopen(suggestion) else {
            throw SpendingIntentError.saveFailed(suggestions.errorMessage ?? "")
        }
        return .result(dialog: "\(SpendingIntentConstants.suggestionUndoneMessage)")
    }
}

struct DismissSuggestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Ignorar compra sugerida"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Compra")
    var suggestionID: String

    @Dependency private var expenses: ExpenseStore
    @Dependency private var suggestions: SuggestionStore

    init() {}

    init(suggestionID: UUID) {
        self.suggestionID = suggestionID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SuggestionCatalog.prepared(expenses: expenses, suggestions: suggestions)
        let suggestion = try SuggestionCatalog.suggestion(suggestionID, in: suggestions)
        guard await suggestions.dismiss(suggestion) else {
            throw SpendingIntentError.saveFailed(suggestions.errorMessage ?? "")
        }
        return .result(dialog: "\(SpendingIntentConstants.suggestionDismissedMessage)")
    }
}

struct MoveSuggestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Mover compra lançada"
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
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SuggestionCatalog.prepared(expenses: expenses, suggestions: suggestions)
        let suggestion = try SuggestionCatalog.suggestion(suggestionID, in: suggestions)
        let expense = try SuggestionCatalog.expense(expenseID, in: expenses)
        guard await suggestions.move(suggestion, to: expense) else {
            throw SpendingIntentError.saveFailed(suggestions.errorMessage ?? "")
        }
        return .result(dialog: "Movido para \(expense.name).")
    }
}

struct OpenSuggestionReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Revisar compras da Carteira"
    static let description = IntentDescription("Abre o Finanças na lista de compras da Carteira que ainda não entraram nos gastos do mês.")
    static let openAppWhenRun = true

    @Dependency private var navigation: AppNavigation

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.reviewSuggestions()
        return .result()
    }
}
