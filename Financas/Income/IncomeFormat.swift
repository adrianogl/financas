import Foundation

enum IncomeFormat {
    static let locale = Locale(identifier: "pt_BR")

    static func monthName(_ month: YearMonth, locale: Locale = locale) -> String {
        formatter(locale).standaloneMonthSymbols[month.month - 1].lowercased(with: locale)
    }

    static func monthTitle(_ month: YearMonth, locale: Locale = locale) -> String {
        let name = monthName(month, locale: locale)
        return name.prefix(1).uppercased(with: locale) + name.dropFirst() + " de \(month.year)"
    }

    static func shortMonth(_ month: YearMonth, locale: Locale = locale) -> String {
        clean(formatter(locale).shortMonthSymbols[month.month - 1], locale)
    }

    static func shortMonthYear(_ month: YearMonth, locale: Locale = locale) -> String {
        "\(shortMonth(month, locale: locale))/\(month.year)"
    }

    static func shortDate(_ day: CalendarDay, locale: Locale = locale) -> String {
        let formatter = formatter(locale)
        let weekday = formatter.shortStandaloneWeekdaySymbols[day.weekday - 1]
        let month = formatter.shortMonthSymbols[day.month - 1]
        return "\(clean(weekday, locale)), \(day.day) \(clean(month, locale))"
    }

    static func currency(_ value: Decimal, locale: Locale = locale) -> String {
        value.formatted(.currency(code: IncomeConstants.currencyCode).locale(locale))
    }

    static func rule(for income: Income, rate: Decimal?, nonBusinessDay: NonBusinessDayRule, locale: Locale = locale) -> String {
        let day = "Todo dia \(income.dayOfMonth ?? 1)"
        guard income.kind == .hourly, let rate, let hours = income.hoursPerDay else {
            return nonBusinessDay.ruleSuffix.map { "\(day) · \($0)" } ?? day
        }
        let rateText = rate.formatted(.currency(code: IncomeConstants.currencyCode).precision(.fractionLength(0...2)).locale(locale))
        return "\(day) · \(rateText)/h · \(hours.formatted(.number.locale(locale)))h/dia"
    }

    static func occurrenceTitle(_ occurrence: IncomeOccurrence, locale: Locale = locale) -> String {
        guard let reference = occurrence.referenceMonth else { return occurrence.income.name }
        return "\(occurrence.income.name) · \(monthName(reference, locale: locale))"
    }

    private static func formatter(_ locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter
    }

    private static func clean(_ symbol: String, _ locale: Locale) -> String {
        symbol.replacingOccurrences(of: ".", with: "").lowercased(with: locale)
    }
}
