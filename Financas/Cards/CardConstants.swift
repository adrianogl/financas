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
    static let meuPluggyConnectorID = 200
    static let pluggyConnectScript = "https://cdn.pluggy.ai/pluggy-connect/v2.9.2/pluggy-connect.js"
    static let pluggyConnectBaseURL = "https://connect.pluggy.ai"
    static let meuPluggyURL = "https://meu.pluggy.ai"
    static let pluggyMessageHandler = "pluggy"
    static let connectionsIntro = "Os cartões chegam pelo MeuPluggy, que usa o Open Finance. Os dados atualizam uma vez por dia."
    static let connectionsSwipeHint = "Arraste uma conexão para a esquerda para remover."
    static let connectIntroTitle = "Você vai precisar de uma conta no MeuPluggy."
    static let connectIntroSteps = [
        "Crie a conta grátis em meu.pluggy.ai e conecte seus bancos por lá.",
        "Volte aqui e toque em Continuar.",
        "Entre com a conta do MeuPluggy e autorize o Finanças.",
    ]
    static let connectFailedMessage = "Não foi possível concluir a conexão. Tente de novo."
    static let nicknamePrompt = "Apelido do cartão"
}
