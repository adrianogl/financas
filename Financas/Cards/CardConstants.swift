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
    static let commitmentMonthCount = 12
    static let endingWindowMonths = 3
    static let loadHistoryMonths = 13
    static let connectionStaleDays = 3
    static let reviewPreviewCount = 3
    static let fixedPreviewCompact = 2
    static let fixedPreviewLandscape = 6
    static let fixedPreviewPortrait = 8
    static let otherInstallmentsPreview = 3
    static let chartHeightCompact: CGFloat = 120
    static let chartHeightLandscape: CGFloat = 170
    static let chartHeightPortrait: CGFloat = 190
    static let cardCornerRadius: CGFloat = 26
    static let pillOpacity = 0.14
    static let chipOpacity = 0.14
    static let reviewBorderOpacity = 0.45
    static let reviewDotSize: CGFloat = 30
    static let reviewDotOpacity = 0.2
    static let loadFailedMessage = "Não foi possível carregar seus cartões. Tente de novo."
    static let syncFailedMessage = "Não foi possível atualizar os cartões agora. Mostrando os dados da última atualização."
}
