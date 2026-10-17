import Foundation

@MainActor
final class ReminderScheduler {
    private let center: ReminderCenter
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(center: ReminderCenter, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.center = center
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
    }

    func requestPermissionIfNeeded(hasIncomes: Bool) async {
        guard hasIncomes, !defaults.bool(forKey: ReminderConstants.permissionAskedKey) else { return }
        if await center.authorization() == .notDetermined {
            _ = await center.requestAuthorization()
        }
        defaults.set(true, forKey: ReminderConstants.permissionAskedKey)
    }

    func reschedule(items: [DueItem], clearingDelivered: Bool) async {
        guard await center.authorization() == .allowed else { return }
        await center.replacePending(with: ReminderPlanner.plan(items: items, now: now(), calendar: calendar))
        if clearingDelivered {
            await center.removeDelivered()
        }
    }

    func reset() async {
        await center.removeAll()
    }
}
