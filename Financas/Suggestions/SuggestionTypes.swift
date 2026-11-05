import Foundation

struct SuggestionSnapshot: Equatable, Sendable {
    var suggestions: [SpendingSuggestion]
    var rules: [MerchantSpendingRule]

    static let empty = SuggestionSnapshot(suggestions: [], rules: [])
}

struct SuggestionPurchase: Equatable, Sendable {
    var merchant: String
    var card: String
    var amount: Decimal
    var occurredAt: Date
}

struct SuggestionReport: Decodable, Equatable, Sendable {
    let suggestion: SpendingSuggestion
    let created: Bool
}

struct SuggestionConfirmation: Decodable, Equatable, Sendable {
    let suggestion: SpendingSuggestion
    let already: Bool
}

struct SuggestionDevice: Equatable, Sendable {
    let id: UUID
    let name: String
}
