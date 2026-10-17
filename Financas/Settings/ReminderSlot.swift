enum ReminderSlot: CaseIterable {
    case overdueMorning
    case overdueEvening
    case dueToday

    var title: String {
        switch self {
        case .overdueMorning: "Atrasadas de manhã"
        case .overdueEvening: "Atrasadas à noite"
        case .dueToday: "Prevista para hoje"
        }
    }

    var enabled: WritableKeyPath<AccountSettings, Bool> {
        switch self {
        case .overdueMorning: \.overdueMorningEnabled
        case .overdueEvening: \.overdueEveningEnabled
        case .dueToday: \.dueTodayEnabled
        }
    }

    var time: WritableKeyPath<AccountSettings, ReminderTime> {
        switch self {
        case .overdueMorning: \.overdueMorningTime
        case .overdueEvening: \.overdueEveningTime
        case .dueToday: \.dueTodayTime
        }
    }
}
