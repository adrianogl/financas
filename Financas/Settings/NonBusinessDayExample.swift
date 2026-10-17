import Foundation

enum NonBusinessDayExample {
    static func text(rule: NonBusinessDayRule, locale: Locale = IncomeFormat.locale) -> String {
        let day = SettingsConstants.exampleDay
        let due = BusinessCalendar.dueDate(for: day, rule: rule)
        let opening = "Dia \(day.day) de \(IncomeFormat.monthName(day.yearMonth, locale: locale)) de \(day.year) é \(weekday(day, locale))"
        guard due != day else { return "\(opening) e fica nesse dia." }
        return "\(opening) e cai em \(due.day) de \(IncomeFormat.monthName(due.yearMonth, locale: locale))."
    }

    private static func weekday(_ day: CalendarDay, _ locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.standaloneWeekdaySymbols[day.weekday - 1].lowercased(with: locale)
    }
}
