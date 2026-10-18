struct ExpenseMonthList {
    let open: [ExpenseOccurrence]
    let paid: [ExpenseOccurrence]

    init(occurrences: [ExpenseOccurrence]) {
        open = occurrences.filter { $0.status != .paid }.sorted(by: Self.openOrder)
        paid = occurrences.filter { $0.status == .paid }
    }

    var all: [ExpenseOccurrence] {
        open + paid
    }

    private static func openOrder(_ lhs: ExpenseOccurrence, _ rhs: ExpenseOccurrence) -> Bool {
        let lhsOverdue = lhs.status == .overdue
        let rhsOverdue = rhs.status == .overdue
        if lhsOverdue != rhsOverdue {
            return lhsOverdue
        }
        if lhsOverdue, lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return (lhs.dueDate, lhs.expense.name) < (rhs.dueDate, rhs.expense.name)
    }
}
