import Foundation

enum ExpenseFormat {
    static func origin(_ occurrence: ExpenseOccurrence, locale: Locale = IncomeFormat.locale) -> String {
        if let paidOn = occurrence.bill?.paidOn, occurrence.bill?.paidAmount != nil {
            return "paga em \(IncomeFormat.shortDate(paidOn, locale: locale))"
        }
        if occurrence.hasBill {
            return "conta lançada"
        }
        switch occurrence.estimate {
        case .average(_, let months):
            return "estimado pela média de \(list(months.map { shortMonth($0, locale) }))"
        case .manual:
            return "estimado"
        }
    }

    static func rule(_ term: ExpenseTerm, estimate: ExpenseEstimate) -> String {
        let day = "Todo dia \(term.dayOfMonth)"
        switch estimate {
        case .average(_, let months):
            return "\(day) · média de \(months.count) meses"
        case .manual:
            return "\(day) · estimado"
        }
    }

    static func occurrenceTitle(_ occurrence: ExpenseOccurrence, today: CalendarDay, locale: Locale = IncomeFormat.locale) -> String {
        guard occurrence.month < today.yearMonth else { return occurrence.expense.name }
        return "\(occurrence.expense.name) · \(IncomeFormat.monthName(occurrence.month, locale: locale))"
    }

    private static func shortMonth(_ month: YearMonth, _ locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.shortMonthSymbols[month.month - 1]
            .replacingOccurrences(of: ".", with: "")
            .lowercased(with: locale)
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.joined() }
        return "\(items.dropLast().joined(separator: ", ")) e \(last)"
    }
}
