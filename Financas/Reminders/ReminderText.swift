import Foundation

enum ReminderText {
    static func overdue(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) receitas atrasadas", "\(IncomeFormat.currency(total(items))) ainda não recebidos.")
        }
        let date = IncomeFormat.shortDate(item.dueDate)
        return ("Receita atrasada", "\(item.title) · \(IncomeFormat.currency(item.amount)), prevista para \(date).")
    }

    static func dueToday(_ items: [DueItem]) -> (title: String, body: String) {
        guard items.count == 1, let item = items.first else {
            return ("\(items.count) receitas previstas para hoje", "\(IncomeFormat.currency(total(items))) no total.")
        }
        return ("Receita prevista para hoje", "\(item.title) · \(IncomeFormat.currency(item.amount))")
    }

    private static func total(_ items: [DueItem]) -> Decimal {
        items.reduce(0) { $0 + $1.amount }
    }
}
