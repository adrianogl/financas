import Foundation
import Testing
@testable import Financas

struct ReminderTimeDateTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    @Test func roundTripsThroughDate() {
        let time = ReminderTime(hour: 7, minute: 30)
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 13))!
        let date = time.date(on: reference, calendar: calendar)
        #expect(calendar.component(.hour, from: date) == 7)
        #expect(calendar.component(.minute, from: date) == 30)
        #expect(ReminderTime(date: date, calendar: calendar) == time)
    }
}
