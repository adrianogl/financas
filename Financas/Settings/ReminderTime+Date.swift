import Foundation

extension ReminderTime {
    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        self.init(hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date))
    }

    func date(on reference: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference) ?? reference
    }
}
