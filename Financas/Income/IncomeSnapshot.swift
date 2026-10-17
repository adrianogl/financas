struct IncomeSnapshot: Equatable, Sendable {
    var incomes: [Income]
    var amounts: [IncomeAmount]
    var receipts: [IncomeReceipt]
    var settings: AccountSettings = .standard

    static let empty = IncomeSnapshot(incomes: [], amounts: [], receipts: [])
}
