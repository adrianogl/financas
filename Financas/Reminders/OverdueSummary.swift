import Foundation

struct OverdueSummary: Equatable {
    let incomeCount: Int
    let expenseCount: Int
    let incoming: Decimal
    let outgoing: Decimal

    init(incomes: [IncomeOccurrence], expenses: [ExpensePayable]) {
        incomeCount = incomes.count
        expenseCount = expenses.count
        incoming = incomes.map(\.expectedAmount).reduce(0, +)
        outgoing = expenses.map(\.amount).reduce(0, +)
    }

    var showsIncomes: Bool {
        incomeCount > 0
    }

    var showsExpenses: Bool {
        expenseCount > 0
    }

    var isEmpty: Bool {
        incomeCount == 0 && expenseCount == 0
    }

    var badgeCount: Int {
        incomeCount + expenseCount
    }

    var showsIncoming: Bool {
        incoming > 0
    }

    var showsOutgoing: Bool {
        outgoing > 0
    }
}
