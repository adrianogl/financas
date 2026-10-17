import Foundation
import Supabase
import Testing
@testable import Financas

struct AccountSettingsTests {
    @Test func standardMatchesTodaysBehavior() {
        let settings = AccountSettings.standard
        #expect(settings.enabledKinds == [.fixed, .hourly, .oneOff])
        #expect(settings.nonBusinessDay == .next)
        #expect(settings.overdueMorningEnabled)
        #expect(settings.overdueMorningTime == ReminderTime(hour: 8, minute: 0))
        #expect(settings.overdueEveningEnabled)
        #expect(settings.overdueEveningTime == ReminderTime(hour: 19, minute: 0))
        #expect(settings.dueTodayEnabled)
        #expect(settings.dueTodayTime == ReminderTime(hour: 8, minute: 0))
    }

    @Test func emptySnapshotUsesStandard() {
        #expect(IncomeSnapshot.empty.settings == .standard)
    }

    @Test func decodesDatabaseRow() throws {
        let json = #"""
        {"user_id":"00000000-0000-0000-0000-0000000000ff","enabled_kinds":["fixed","one_off"],
         "non_business_day":"previous","overdue_morning_enabled":false,"overdue_morning_time":"07:30:00",
         "overdue_evening_enabled":true,"overdue_evening_time":"20:15:00","due_today_enabled":true,
         "due_today_time":"09:00:00","updated_at":"2026-10-17T15:00:00+00:00"}
        """#
        let settings = try SupabaseIncomeService.decoder.decode(AccountSettings.self, from: Data(json.utf8))
        #expect(settings.enabledKinds == [.fixed, .oneOff])
        #expect(settings.nonBusinessDay == .previous)
        #expect(!settings.overdueMorningEnabled)
        #expect(settings.overdueMorningTime == ReminderTime(hour: 7, minute: 30))
        #expect(settings.overdueEveningTime == ReminderTime(hour: 20, minute: 15))
        #expect(settings.dueTodayTime == ReminderTime(hour: 9, minute: 0))
    }

    @Test func decodesTimeWithoutSeconds() throws {
        let time = try JSONDecoder().decode(ReminderTime.self, from: Data(#""07:30""#.utf8))
        #expect(time == ReminderTime(hour: 7, minute: 30))
    }

    @Test func encodesTimeWithSeconds() throws {
        let data = try JSONEncoder().encode(ReminderTime(hour: 7, minute: 5))
        #expect(String(decoding: data, as: UTF8.self) == #""07:05:00""#)
    }

    @Test func cannotDisableLastKind() {
        var settings = AccountSettings.standard
        settings.enabledKinds = [.fixed]
        #expect(!settings.canDisable(.fixed))
        settings.enabledKinds = [.fixed, .hourly]
        #expect(settings.canDisable(.fixed))
    }

    @Test func orderedEnabledKindsFollowsFormOrder() {
        var settings = AccountSettings.standard
        settings.enabledKinds = [.oneOff, .fixed]
        #expect(settings.orderedEnabledKinds == [.fixed, .oneOff])
    }

    @Test func changedColumnsOnlyListsDifferences() {
        var settings = AccountSettings.standard
        settings.nonBusinessDay = .keep
        let columns = settings.changedColumns(from: .standard)
        #expect(Set(columns.keys) == ["non_business_day"])
        #expect(columns["non_business_day"] == .string("keep"))
    }

    @Test func changedColumnsEncodeKindsAndTimes() {
        var settings = AccountSettings.standard
        settings.enabledKinds = [.fixed, .oneOff]
        settings.dueTodayTime = ReminderTime(hour: 7, minute: 30)
        let columns = settings.changedColumns(from: .standard)
        #expect(columns["enabled_kinds"] == .array([.string("fixed"), .string("one_off")]))
        #expect(columns["due_today_time"] == .string("07:30:00"))
        #expect(columns.count == 2)
    }
}
