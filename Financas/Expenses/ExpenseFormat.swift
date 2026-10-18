import Foundation

enum ExpenseFormat {
    static func origin(_ occurrence: ExpenseOccurrence, locale: Locale = IncomeFormat.locale) -> String {
        if let paidOn = occurrence.paidOn {
            return "paga em \(IncomeFormat.shortDate(paidOn, locale: locale))"
        }
        if occurrence.hasBill {
            return "conta lançada"
        }
        switch occurrence.estimate {
        case .average(_, let months):
            return "estimado pela média de \(list(months.map { IncomeFormat.shortMonth($0, locale: locale) }))"
        case .manual:
            return "estimado"
        case .fixed:
            return "valor fixo"
        case .parts:
            return "soma das partes"
        }
    }

    static func origin(_ value: ExpensePartValue, locale: Locale = IncomeFormat.locale) -> String {
        switch value.origin {
        case .paid:
            guard let paidOn = value.bill?.paidOn else { return "paga" }
            return "paga em \(IncomeFormat.shortDate(paidOn, locale: locale))"
        case .bill:
            return "conta lançada"
        case .fixed:
            return "valor fixo"
        case .average(let months):
            return "estimado pela média de \(list(months.map { IncomeFormat.shortMonth($0, locale: locale) }))"
        case .estimated:
            return "estimado"
        }
    }

    static func rule(_ term: ExpenseTerm, estimate: ExpenseEstimate, partCount: Int) -> String {
        let day = "Todo dia \(term.dayOfMonth)"
        switch estimate {
        case .average(_, let months):
            return "\(day) · média de \(months.count) meses"
        case .manual:
            return "\(day) · estimado"
        case .fixed:
            return "\(day) · valor fixo"
        case .parts:
            return "\(day) · \(partCount) \(partCount == 1 ? "parte" : "partes")"
        }
    }

    static func partNames(_ values: [ExpensePartValue], locale: Locale = IncomeFormat.locale) -> String {
        list(values.map { $0.part.name.lowercased(with: locale) })
    }

    static func partCaption(_ value: ExpensePartValue, change: Decimal?, previous: YearMonth, locale: Locale = IncomeFormat.locale) -> String {
        guard !value.isFixed else { return "fixo" }
        guard let change else { return "varia" }
        guard change != 0 else { return "igual a \(IncomeFormat.monthName(previous, locale: locale))" }
        let arrow = change < 0 ? "▼" : "▲"
        return "\(arrow) \(IncomeFormat.currency(abs(change), locale: locale)) vs. \(IncomeFormat.monthName(previous, locale: locale))"
    }

    static func partStatus(_ value: ExpensePartValue) -> String {
        switch value.status {
        case .paid:
            guard let paidOn = value.bill?.paidOn else { return "paga" }
            return "paga em \(DueText.shortDate(paidOn))"
        case .overdue:
            return "atrasada"
        case .pending:
            return "vence \(DueText.shortDate(value.dueDate))"
        }
    }

    static func spendingRule(_ expected: Decimal, locale: Locale = IncomeFormat.locale) -> String {
        "Gasto do mês · previsto \(IncomeFormat.currency(expected, locale: locale))"
    }

    static func tableAmount(_ value: Decimal, locale: Locale = IncomeFormat.locale) -> String {
        var source = value
        var whole = Decimal()
        NSDecimalRound(&whole, &source, 0, .plain)
        let fraction = whole == value ? 0 : 2
        return value.formatted(.number.precision(.fractionLength(fraction)).locale(locale))
    }

    static func occurrenceTitle(_ occurrence: ExpenseOccurrence, today: CalendarDay, locale: Locale = IncomeFormat.locale) -> String {
        guard occurrence.month < today.yearMonth else { return occurrence.expense.name }
        return "\(occurrence.expense.name) · \(IncomeFormat.monthName(occurrence.month, locale: locale))"
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.joined() }
        return "\(items.dropLast().joined(separator: ", ")) e \(last)"
    }
}
