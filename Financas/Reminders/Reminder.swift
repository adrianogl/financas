struct Reminder: Hashable, Sendable {
    let id: String
    let day: CalendarDay
    let hour: Int
    let title: String
    let body: String
    let route: ReminderRoute
}
