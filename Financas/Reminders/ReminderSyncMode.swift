import SwiftUI

struct ReminderSyncMode: Equatable {
    let asksPermission: Bool
    let clearingDelivered: Bool

    static func current(phase: ScenePhase, isUnlocked: Bool) -> ReminderSyncMode? {
        guard phase == .active else { return nil }
        return ReminderSyncMode(asksPermission: isUnlocked, clearingDelivered: true)
    }
}
