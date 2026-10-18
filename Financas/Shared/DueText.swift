enum DueText {
    static func text(dueDate: CalendarDay, today: CalendarDay) -> String {
        let days = today.days(until: dueDate)
        if days == 0 { return "vence hoje" }
        if days > 0 { return "vence \(shortDate(dueDate)) · \(relative(dueDate: dueDate, today: today))" }
        return relative(dueDate: dueDate, today: today)
    }

    static func relative(dueDate: CalendarDay, today: CalendarDay) -> String {
        let days = today.days(until: dueDate)
        if days == 0 { return "hoje" }
        if days > 0 { return "daqui a \(dayCount(days))" }
        return "atrasada há \(dayCount(-days))"
    }

    static func shortDate(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }

    private static func dayCount(_ days: Int) -> String {
        "\(days) \(days == 1 ? "dia" : "dias")"
    }
}
