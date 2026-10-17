import Foundation
import Observation

@MainActor
@Observable
final class ReminderScheduler {
    @ObservationIgnored private let center: ReminderCenter
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var lastWork: Task<Void, Never>?

    init(center: ReminderCenter, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }, calendar: Calendar = .autoupdatingCurrent) {
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

    func requestPermissionFromSettings() async {
        guard await center.authorization() == .notDetermined else { return }
        _ = await center.requestAuthorization()
        defaults.set(true, forKey: ReminderConstants.permissionAskedKey)
    }

    func authorization() async -> ReminderAuthorization {
        await center.authorization()
    }

    func reschedule(items: [DueItem], settings: AccountSettings, clearingDelivered: Bool) async {
        await enqueue {
            guard await self.center.authorization() == .allowed else { return }
            await self.center.replacePending(with: ReminderPlanner.plan(items: items, settings: settings, now: self.now(), calendar: self.calendar))
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
