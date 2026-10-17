import Observation

@MainActor
@Observable
final class ReminderRouter {
    private(set) var pendingRoute: ReminderRoute?

    func receive(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo[ReminderConstants.routeKey] as? String, let route = ReminderRoute(rawValue: raw) else { return }
        pendingRoute = route
    }

    func take(isUnlocked: Bool) -> ReminderRoute? {
        guard isUnlocked, let route = pendingRoute else { return nil }
        pendingRoute = nil
        return route
    }
}
