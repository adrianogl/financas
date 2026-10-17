enum DueText {
    static func text(dueDate: CalendarDay, today: CalendarDay) -> String {
        let days = today.days(until: dueDate)
        if days == 0 { return "vence hoje" }
        if days > 0 {
            return "vence \(shortDate(dueDate)) · daqui a \(days) \(days == 1 ? "dia" : "dias")"
        }
        let late = -days
        return "atrasada há \(late) \(late == 1 ? "dia" : "dias")"
    }

    private static func shortDate(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }
}
