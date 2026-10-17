@MainActor
protocol ReminderCenter {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async -> Bool
    func replacePending(with reminders: [Reminder]) async
    func removeDelivered() async
    func removeAll() async
}
