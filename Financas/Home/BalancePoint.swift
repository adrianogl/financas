struct BalancePoint: Identifiable, Equatable {
    let day: Int
    let balance: Double

    var id: String { "\(day)-\(balance)" }
}
