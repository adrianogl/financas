import Supabase

extension AccountSettings {
    func changedColumns(from previous: AccountSettings) -> [String: AnyJSON] {
        var columns: [String: AnyJSON] = [:]
        if orderedEnabledKinds != previous.orderedEnabledKinds {
            columns[CodingKeys.enabledKinds.rawValue] = .array(orderedEnabledKinds.map { .string($0.rawValue) })
        }
        if nonBusinessDay != previous.nonBusinessDay {
            columns[CodingKeys.nonBusinessDay.rawValue] = .string(nonBusinessDay.rawValue)
        }
        add(\.overdueMorningEnabled, .overdueMorningEnabled, previous, to: &columns)
        add(\.overdueEveningEnabled, .overdueEveningEnabled, previous, to: &columns)
        add(\.dueTodayEnabled, .dueTodayEnabled, previous, to: &columns)
        add(\.overdueMorningTime, .overdueMorningTime, previous, to: &columns)
        add(\.overdueEveningTime, .overdueEveningTime, previous, to: &columns)
        add(\.dueTodayTime, .dueTodayTime, previous, to: &columns)
        return columns
    }

    private func add(_ path: KeyPath<AccountSettings, Bool>, _ key: CodingKeys, _ previous: AccountSettings, to columns: inout [String: AnyJSON]) {
        guard self[keyPath: path] != previous[keyPath: path] else { return }
        columns[key.rawValue] = .bool(self[keyPath: path])
    }

    private func add(_ path: KeyPath<AccountSettings, ReminderTime>, _ key: CodingKeys, _ previous: AccountSettings, to columns: inout [String: AnyJSON]) {
        guard self[keyPath: path] != previous[keyPath: path] else { return }
        columns[key.rawValue] = .string(self[keyPath: path].text)
    }
}
