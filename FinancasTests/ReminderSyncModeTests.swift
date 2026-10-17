import SwiftUI
import Testing
@testable import Financas

struct ReminderSyncModeTests {
    @Test func activeAndUnlockedAsksAndClearsDelivered() {
        #expect(ReminderSyncMode.current(phase: .active, isUnlocked: true) == ReminderSyncMode(asksPermission: true, clearingDelivered: true))
    }

    @Test func activeAndLockedDoesNotAsk() {
        #expect(ReminderSyncMode.current(phase: .active, isUnlocked: false) == ReminderSyncMode(asksPermission: false, clearingDelivered: true))
    }

    @Test func doesNotSyncOutsideActive() {
        for phase in [ScenePhase.background, .inactive] {
            for isUnlocked in [true, false] {
                #expect(ReminderSyncMode.current(phase: phase, isUnlocked: isUnlocked) == nil)
            }
        }
    }
}
