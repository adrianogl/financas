struct IncomeSnapshot: Equatable, Sendable {
    var incomes: [Income]
    var amounts: [IncomeAmount]
    var receipts: [IncomeReceipt]

    static let empty = IncomeSnapshot(incomes: [], amounts: [], receipts: [])
}
