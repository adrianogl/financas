struct ExpenseSnapshot: Equatable, Sendable {
    var expenses: [Expense]
    var terms: [ExpenseTerm]
    var bills: [ExpenseBill]

    static let empty = ExpenseSnapshot(expenses: [], terms: [], bills: [])
}
