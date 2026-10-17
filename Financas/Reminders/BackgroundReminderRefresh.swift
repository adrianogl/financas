import Foundation

@MainActor
enum BackgroundReminderRefresh {
    static func run(
        hasSession: () async -> Bool,
        store: IncomeStore,
        reschedule: ([DueItem]) async -> Void
    ) async {
        guard await hasSession(), await store.refresh(), let items = store.dueItems else { return }
        await reschedule(items)
    }
}
