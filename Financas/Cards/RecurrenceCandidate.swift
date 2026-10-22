import Foundation

struct RecurrenceCandidate: Hashable, Identifiable, Sendable {
    let cardAccountID: UUID
    let merchantKey: String
    let name: String
    let monthCount: Int
    let typicalAmount: Decimal
    let chargedAfterEnd: Bool

    var id: String { "\(cardAccountID)|\(merchantKey)" }
}
