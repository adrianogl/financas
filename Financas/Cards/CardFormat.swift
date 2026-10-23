import Foundation

enum CardFormat {
    static func endingText(_ plan: InstallmentPlan, locale: Locale = IncomeFormat.locale) -> String {
        "\(plan.totalInstallments)/\(plan.totalInstallments) em \(IncomeFormat.monthName(plan.lastMonth, locale: locale))"
    }

    static func releasesText(_ plan: InstallmentPlan, locale: Locale = IncomeFormat.locale) -> String {
        "libera em \(IncomeFormat.shortMonth(plan.releasesIn, locale: locale))"
    }

    static func progressText(_ plan: InstallmentPlan, today: CalendarDay, locale: Locale = IncomeFormat.locale) -> String {
        let last = plan.lastMonth
        var month = IncomeFormat.shortMonth(last, locale: locale)
        if last.year != today.year {
            month += String(format: "/%02d", last.year % 100)
        }
        return "\(plan.lastSeenNumber)/\(plan.totalInstallments) · até \(month)"
    }

    static func syncText(_ date: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return "Ainda não atualizado" }
        if calendar.isDate(date, inSameDayAs: now) {
            return "Atualizado hoje, \(format(date, "HH:mm", calendar: calendar))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Atualizado ontem"
        }
        return "Atualizado em \(format(date, "dd/MM", calendar: calendar))"
    }

    static func statusText(_ connection: CardConnection, now: Date, calendar: Calendar = .current) -> String {
        switch connection.status {
        case .needsReconnect:
            return "Precisa reconectar"
        case .error:
            return "Falha ao atualizar"
        case .active:
            let text = syncText(connection.lastSyncedAt, now: now, calendar: calendar)
            return text.split(separator: ",").first.map(String.init) ?? text
        }
    }

    static func accountDetailText(institution: String?, brandLabel: String?, lastDigits: String) -> String {
        let labels = [institution, brandLabel]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let digits = "····\(lastDigits)"
        return labels.isEmpty ? digits : "\(labels) \(digits)"
    }

    static func connectionWarning(_ connection: CardConnection, nickname: String, now: Date, calendar: Calendar = .current) -> String? {
        if connection.status == .needsReconnect {
            return "\(nickname) precisa reconectar"
        }
        guard let synced = connection.lastSyncedAt else { return nil }
        let start = calendar.startOfDay(for: synced)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        guard days > CardConstants.connectionStaleDays else { return nil }
        return "\(nickname) sem atualizar desde \(format(synced, "dd/MM", calendar: calendar))"
    }

    static func reviewTitle(_ count: Int) -> String {
        count == 1 ? "1 recorrência para revisar" : "\(count) recorrências para revisar"
    }

    static func candidateText(monthCount: Int, amount: Decimal, locale: Locale = IncomeFormat.locale) -> String {
        let months = monthCount == 1 ? "1 mês" : "\(monthCount) meses"
        return "\(months) · ~\(IncomeFormat.currency(amount, locale: locale))"
    }

    private static func format(_ date: Date, _ pattern: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = IncomeFormat.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
