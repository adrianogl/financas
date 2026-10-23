struct SidebarCounts: Equatable {
    let incomes: Int
    let expenses: Int
    let overdue: Int
    let cards: Int

    init(incomes: [IncomeOccurrence], expenses: [ExpenseOccurrence], overdue: Int, cards: Int) {
        self.incomes = incomes.filter { $0.status != .received }.count
        self.expenses = expenses.filter { $0.status != .paid }.count
        self.overdue = overdue
        self.cards = cards
    }
}
