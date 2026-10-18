import Foundation

struct AppVersion: Equatable {
    let version: String
    let commit: String?
    let builtAt: Date?

    init(info: [String: Any]) {
        version = info["CFBundleShortVersionString"] as? String ?? "—"
        commit = info[SettingsConstants.commitKey] as? String
        builtAt = (info[SettingsConstants.builtAtKey] as? String).flatMap { try? Date($0, strategy: .iso8601) }
    }

    static let installed = AppVersion(info: Bundle.main.infoDictionary ?? [:])

    func text(locale: Locale = IncomeFormat.locale, timeZone: TimeZone = .current) -> String {
        var parts = [version]
        if let commit {
            parts.append(commit)
        }
        if let builtAt {
            var style = Date.FormatStyle(locale: locale, timeZone: timeZone)
            style = style.day(.twoDigits).month(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
            parts.append(builtAt.formatted(style))
        }
        return parts.joined(separator: " · ")
    }
}
