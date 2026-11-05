import Foundation

enum SuggestionConstants {
    static let suggestionsTable = "spending_suggestions"
    static let rulesTable = "merchant_spending_rules"
    static let reportFunction = "report_spending_suggestion"
    static let confirmFunction = "confirm_spending_suggestion"
    static let reopenFunction = "reopen_spending_suggestion"
    static let moveFunction = "move_spending_suggestion"
    static let historyDays = 60
    static let alternativesCount = 2
    static let installmentDayTolerance = 2
    static let installmentAmountTolerance = Decimal(string: "0.10") ?? 0
    static let deviceIDKey = "suggestionDeviceID"
    static let loadFailedMessage = "Não foi possível carregar as compras para revisar. Tente de novo."
}
