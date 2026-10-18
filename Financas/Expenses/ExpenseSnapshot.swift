struct ExpenseSnapshot: Equatable, Sendable {
    var expenses: [Expense]
    var terms: [ExpenseTerm]
    var bills: [ExpenseBill]
    var parts: [ExpensePart] = []
    var partTerms: [ExpensePartTerm] = []
    var entries: [ExpenseEntry] = []
    var partBills: [ExpensePartBill] = []

    static let empty = ExpenseSnapshot(expenses: [], terms: [], bills: [])
}
