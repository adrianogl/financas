import Foundation

enum ReminderPlanner {
    static func plan(items: [DueItem], now: Date, calendar: Calendar) -> [Reminder] {
        let today = CalendarDay(date: now, calendar: calendar)
        var reminders: [Reminder] = []
        for offset in 0..<ReminderConstants.windowDays {
            let day = today.adding(days: offset)
            let overdue = items.filter { $0.dueDate < day }
            let dueToday = items.filter { $0.dueDate == day }
            if !overdue.isEmpty {
                let text = ReminderText.overdue(overdue)
                for hour in [ReminderConstants.morningHour, ReminderConstants.eveningHour] {
                    reminders.append(Reminder(id: id("overdue", day, hour), day: day, hour: hour, title: text.title, body: text.body, route: .overdue))
                }
            }
            if !dueToday.isEmpty {
                let text = ReminderText.dueToday(dueToday)
                let hour = ReminderConstants.morningHour
                reminders.append(Reminder(id: id("due", day, hour), day: day, hour: hour, title: text.title, body: text.body, route: .incomes))
            }
        }
        return reminders.filter { fireDate($0, calendar: calendar) > now }
    }

    private static func id(_ prefix: String, _ day: CalendarDay, _ hour: Int) -> String {
        "\(prefix)-\(day.text)-\(String(format: "%02d", hour))"
    }

    private static func fireDate(_ reminder: Reminder, calendar: Calendar) -> Date {
        let components = DateComponents(year: reminder.day.year, month: reminder.day.month, day: reminder.day.day, hour: reminder.hour)
        return calendar.date(from: components) ?? .distantPast
    }
}
