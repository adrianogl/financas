import Foundation

struct CardRecurrence: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var cardAccountID: UUID
    var merchantKey: String
    var status: CardRecurrenceStatus
    var endedOn: CalendarDay?

    enum CodingKeys: String, CodingKey {
        case id
        case cardAccountID = "card_account_id"
        case merchantKey = "merchant_key"
        case status
        case endedOn = "ended_on"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardAccountID, forKey: .cardAccountID)
        try container.encode(merchantKey, forKey: .merchantKey)
        try container.encode(status, forKey: .status)
        try container.encode(endedOn, forKey: .endedOn)
    }
}
