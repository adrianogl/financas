struct Reminder: Hashable, Sendable {
    let id: String
    let day: CalendarDay
    let time: ReminderTime
    let title: String
    let body: String
    let route: ReminderRoute
}
