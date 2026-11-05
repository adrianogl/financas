import Foundation

enum SpendingIntentConstants {
    static let unavailableMessage = "Não consegui carregar seus gastos. Abra o Finanças, confira se está logado e tente de novo."
    static let noSpendingsMessage = "Você ainda não tem gasto do mês. Crie um no Finanças, como \"Padaria\" ou \"Avulsos\"."
    static let invalidAmountMessage = "Informe um valor maior que zero."
    static let saveFailedMessage = "Não consegui lançar o gasto. Tente de novo."
    static let entryGoneMessage = "Esse lançamento já foi apagado."
    static let undoneMessage = "Lançamento desfeito."
    static let invalidMerchantMessage = "A automação não mandou o nome do estabelecimento."
    static let suggestionGoneMessage = "Essa compra não está mais para revisar."
    static let suggestionUndoneMessage = "Lançamento desfeito. A compra ficou em Revisar compras."
    static let suggestionDismissedMessage = "Certo, essa compra não entra nos gastos do mês."
}
