import Foundation

enum CardConstants {
    static let connectionsTable = "card_connections"
    static let accountsTable = "card_accounts"
    static let transactionsTable = "card_transactions"
    static let recurrencesTable = "card_recurrences"
    static let syncFunction = "cards-sync"
    static let connectFunction = "cards-connect"
    static let pageSize = 1000
    static let installmentDropAfterMonths = 3
    static let recurrenceWindowMonths = 12
    static let recurrenceMinimumMonths = 3
    static let recurrenceAmountTolerance: Decimal = 0.10
    static let fixedChargeStaleDays = 45
}
