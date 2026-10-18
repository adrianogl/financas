import Foundation

struct ExpenseDraft: Equatable {
    var name: String
    var isFixed: Bool
    var estimatedAmount: Decimal?
    var dayOfMonth: Int
    var startMonth: YearMonth
    var endMonth: YearMonth?
    let expenseID: UUID
    let isNew: Bool
    private let newTermID: UUID
    private let currentTerm: ExpenseTerm?
    private let knownTerms: [ExpenseTerm]

    init(today: CalendarDay) {
        name = ""
        isFixed = true
        estimatedAmount = nil
        dayOfMonth = 1
        startMonth = today.yearMonth
        endMonth = nil
        expenseID = UUID()
        isNew = true
        newTermID = UUID()
        currentTerm = nil
        knownTerms = []
    }

    init(expense: Expense, snapshot: ExpenseSnapshot, today: CalendarDay) {
        let term = ExpenseSchedule.term(for: expense, in: today.yearMonth, snapshot: snapshot)
        name = expense.name
        isFixed = expense.isFixed
        estimatedAmount = term?.estimatedAmount
        dayOfMonth = term?.dayOfMonth ?? 1
        startMonth = expense.startMonth
        endMonth = expense.endMonth
        expenseID = expense.id
        isNew = false
        newTermID = UUID()
        currentTerm = term
        knownTerms = snapshot.terms.filter { $0.expenseID == expense.id }
    }

    var validationMessage: String? {
        if trimmedName.isEmpty {
            return "Dê um nome para a despesa."
        }
        guard let estimatedAmount, estimatedAmount > 0 else {
            return "Informe um valor maior que zero."
        }
        if let endMonth, endMonth < startMonth {
            return "O mês de fim precisa ser depois do início."
        }
        return nil
    }

    func build(today: CalendarDay) -> (Expense, ExpenseTerm?) {
        let expense = Expense(id: expenseID, name: trimmedName, startMonth: startMonth, endMonth: endMonth, isFixed: isFixed)
        let value = estimatedAmount ?? 0

        guard !isNew, let currentTerm else {
            let term = ExpenseTerm(
                id: newTermID,
                expenseID: expenseID,
                validFrom: startMonth,
                estimatedAmount: value,
                dayOfMonth: dayOfMonth,
                averageFrom: startMonth
            )
            return (expense, term)
        }

        let estimateChanged = value != currentTerm.estimatedAmount
        let dayChanged = dayOfMonth != currentTerm.dayOfMonth
        guard estimateChanged || dayChanged else { return (expense, nil) }

        let validFrom = max(today.yearMonth, startMonth)
        let averageFrom: YearMonth
        if estimateChanged {
            averageFrom = validFrom > today.yearMonth ? validFrom : validFrom.next
        } else {
            averageFrom = currentTerm.averageFrom
        }
        let reusedID = knownTerms.first { $0.validFrom == validFrom }?.id ?? newTermID
        let term = ExpenseTerm(
            id: reusedID,
            expenseID: expenseID,
            validFrom: validFrom,
            estimatedAmount: value,
            dayOfMonth: dayOfMonth,
            averageFrom: averageFrom
        )
        return (expense, term)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
