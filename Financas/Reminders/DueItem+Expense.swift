import Foundation

extension DueItem {
    init(expense payable: ExpensePayable) {
        self.init(
            id: payable.id,
            kind: .expense,
            title: payable.title,
            amount: payable.amount,
            dueDate: payable.dueDate
        )
    }
}
