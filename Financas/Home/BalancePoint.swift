struct BalancePoint: Identifiable {
    let day: Int
    let balance: Double

    var id: Int { day }
}
