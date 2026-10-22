struct CardSnapshot: Equatable, Sendable {
    var connections: [CardConnection]
    var accounts: [CardAccount]
    var transactions: [CardTransaction]
    var recurrences: [CardRecurrence]

    static let empty = CardSnapshot(connections: [], accounts: [], transactions: [], recurrences: [])
}
