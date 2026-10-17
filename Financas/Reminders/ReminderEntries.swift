enum ReminderEntries {
    static func exist(incomes: IncomeSnapshot, expenses: ExpenseSnapshot) -> Bool {
        !incomes.incomes.isEmpty || !expenses.expenses.isEmpty
    }
}
