import BackgroundTasks
import Foundation

enum BackgroundRefresh {
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: ReminderConstants.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: ReminderConstants.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
