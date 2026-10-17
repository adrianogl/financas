struct AccountSettings: Equatable, Codable, Sendable {
    var enabledKinds: [IncomeKind]
    var nonBusinessDay: NonBusinessDayRule
    var overdueMorningEnabled: Bool
    var overdueMorningTime: ReminderTime
    var overdueEveningEnabled: Bool
    var overdueEveningTime: ReminderTime
    var dueTodayEnabled: Bool
    var dueTodayTime: ReminderTime

    enum CodingKeys: String, CodingKey {
        case enabledKinds = "enabled_kinds"
        case nonBusinessDay = "non_business_day"
        case overdueMorningEnabled = "overdue_morning_enabled"
        case overdueMorningTime = "overdue_morning_time"
        case overdueEveningEnabled = "overdue_evening_enabled"
        case overdueEveningTime = "overdue_evening_time"
        case dueTodayEnabled = "due_today_enabled"
        case dueTodayTime = "due_today_time"
    }

    static let standard = AccountSettings(
        enabledKinds: IncomeFormConstants.kinds,
        nonBusinessDay: .next,
        overdueMorningEnabled: true,
        overdueMorningTime: ReminderTime(hour: 8, minute: 0),
        overdueEveningEnabled: true,
        overdueEveningTime: ReminderTime(hour: 19, minute: 0),
        dueTodayEnabled: true,
        dueTodayTime: ReminderTime(hour: 8, minute: 0)
    )

    var orderedEnabledKinds: [IncomeKind] {
        IncomeFormConstants.kinds.filter(enabledKinds.contains)
    }

    func canDisable(_ kind: IncomeKind) -> Bool {
        orderedEnabledKinds.contains { $0 != kind }
    }
}
