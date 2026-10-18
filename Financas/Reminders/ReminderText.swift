import Foundation

enum ReminderText {
    static func overdue(_ items: [DueItem]) -> (title: String, body: String) {
        let incomes = items.filter { $0.kind == .income }
        let expenses = items.filter { $0.kind == .expense }
        if !incomes.isEmpty, !expenses.isEmpty {
            return mixed(prefix: "Atrasadas", incomes: incomes, expenses: expenses)
        }
        if expenses.isEmpty {
            return incomeOverdue(incomes)
        }
        return expenseOverdue(expenses)
    }

    static func dueToday(_ items: [DueItem]) -> (title: String, body: String) {
        let incomes = items.filter { $0.kind == .income }
        let expenses = items.filter { $0.kind == .expense }
        if !incomes.isEmpty, !expenses.isEmpty {
            return mixed(prefix: "Hoje", incomes: incomes, expenses: expenses)
        }
        if expenses.isEmpty {
            return incomeDueToday(incomes)
        }
        return expenseDueToday(expenses)
    }

    private static func incomeOverdue(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) receitas atrasadas", "\(IncomeFormat.currency(total(items))) ainda não recebidos.")
        }
        let date = IncomeFormat.shortDate(item.dueDate)
        return ("Receita atrasada", "\(item.title) · \(IncomeFormat.currency(item.amount)), prevista para \(date).")
    }

    private static func incomeDueToday(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) receitas previstas para hoje", "\(IncomeFormat.currency(total(items))) no total.")
        }
        return ("Receita prevista para hoje", "\(item.title) · \(IncomeFormat.currency(item.amount))")
    }

    private static func expenseOverdue(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) contas atrasadas", "\(IncomeFormat.currency(total(items))) ainda não pagos.")
        }
        let date = IncomeFormat.shortDate(item.dueDate)
        return ("Conta atrasada", "\(item.title) · \(IncomeFormat.currency(item.amount)), venceu em \(date).")
    }

    private static func expenseDueToday(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) contas vencem hoje", "\(IncomeFormat.currency(total(items))) no total.")
        }
        return ("Conta vence hoje", "\(item.title) · \(IncomeFormat.currency(item.amount))")
    }

    private static func mixed(prefix: String, incomes: [DueItem], expenses: [DueItem]) -> (title: String, body: String) {
        let title = "\(prefix): \(count(incomes.count, "receita")) e \(count(expenses.count, "conta"))"
        let body = "\(IncomeFormat.currency(total(incomes))) a receber e \(IncomeFormat.currency(total(expenses))) a pagar."
        return (title, body)
    }

    private static func count(_ number: Int, _ noun: String) -> String {
        "\(number) \(noun)\(number == 1 ? "" : "s")"
    }

    private static func total(_ items: [DueItem]) -> Decimal {
        items.reduce(0) { $0 + $1.amount }
    }
}
