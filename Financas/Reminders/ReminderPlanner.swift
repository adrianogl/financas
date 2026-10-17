import Foundation

enum ReminderPlanner {
    static func plan(items: [DueItem], settings: AccountSettings, now: Date, calendar: Calendar) -> [Reminder] {
        let today = CalendarDay(date: now, calendar: calendar)
        let overdueTimes = overdueTimes(settings)
        var reminders: [Reminder] = []
        for offset in 0..<ReminderConstants.windowDays {
            let day = today.adding(days: offset)
            let overdue = items.filter { $0.dueDate < day }
            let dueToday = items.filter { $0.dueDate == day }
            if !overdue.isEmpty {
                let text = ReminderText.overdue(overdue)
                for time in overdueTimes {
                    reminders.append(Reminder(id: id("overdue", day, time), day: day, time: time, title: text.title, body: text.body, route: .overdue))
                }
            }
            if settings.dueTodayEnabled, !dueToday.isEmpty {
                let text = ReminderText.dueToday(dueToday)
                let time = settings.dueTodayTime
                reminders.append(Reminder(id: id("due", day, time), day: day, time: time, title: text.title, body: text.body, route: .incomes))
            }
        }
        return reminders.filter { fireDate($0, calendar: calendar) > now }
    }

    private static func overdueTimes(_ settings: AccountSettings) -> [ReminderTime] {
        var times: [ReminderTime] = []
        if settings.overdueMorningEnabled {
            times.append(settings.overdueMorningTime)
        }
        if settings.overdueEveningEnabled, !times.contains(settings.overdueEveningTime) {
            times.append(settings.overdueEveningTime)
        }
        return times.sorted()
    }

    private static func id(_ prefix: String, _ day: CalendarDay, _ time: ReminderTime) -> String {
        "\(prefix)-\(day.text)-\(String(format: "%02d%02d", time.hour, time.minute))"
    }

    private static func fireDate(_ reminder: Reminder, calendar: Calendar) -> Date {
        let components = DateComponents(year: reminder.day.year, month: reminder.day.month, day: reminder.day.day, hour: reminder.time.hour, minute: reminder.time.minute)
        return calendar.date(from: components) ?? .distantPast
    }
}
