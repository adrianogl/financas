import Foundation

struct MerchantSpendingRule: Identifiable, Hashable, Decodable, Sendable {
    let id: UUID
    var merchantKey: String
    var expenseID: UUID
    var autoLaunch: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case merchantKey = "merchant_key"
        case expenseID = "expense_id"
        case autoLaunch = "auto_launch"
    }
}
