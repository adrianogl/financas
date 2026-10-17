import Foundation

@MainActor
final class ReminderScheduler {
    private let center: ReminderCenter
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private var lastWork: Task<Void, Never>?

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
        await enqueue {
            guard await self.center.authorization() == .allowed else { return }
            await self.center.replacePending(with: ReminderPlanner.plan(items: items, now: self.now(), calendar: self.calendar))
            if clearingDelivered {
                await self.center.removeDelivered()
            }
        }
    }

    func reset() async {
        await enqueue {
            await self.center.removeAll()
        }
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Void) async {
        let previous = lastWork
        let current = Task {
            await previous?.value
            await work()
        }
        lastWork = current
        await current.value
    }
}
