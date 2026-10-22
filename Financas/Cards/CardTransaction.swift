import Foundation

struct CardTransaction: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var cardAccountID: UUID
    var date: CalendarDay
    var description: String
    var amount: Decimal
    var type: CardTransactionType
    var isPending: Bool
    var installmentNumber: Int?
    var totalInstallments: Int?
    var purchaseDate: CalendarDay?

    enum CodingKeys: String, CodingKey {
        case id
        case cardAccountID = "card_account_id"
        case date
        case description
        case amount
        case type
        case isPending = "is_pending"
        case installmentNumber = "installment_number"
        case totalInstallments = "total_installments"
        case purchaseDate = "purchase_date"
    }
}
