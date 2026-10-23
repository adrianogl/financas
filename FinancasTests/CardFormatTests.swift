import Foundation
import Testing
@testable import Financas

struct CardFormatTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func plan(number: Int, total: Int, seen: YearMonth) -> InstallmentPlan {
        InstallmentPlan(
            cardAccountID: CardSamples.c6.id,
            name: "PlayStation",
            purchaseDate: CardSamples.day(2026, 8, 5),
            installmentAmount: Decimal(string: "112.47")!,
            totalInstallments: total,
            lastSeenNumber: number,
            lastSeenMonth: seen
        )
    }

    @Test func endingText() {
        #expect(CardFormat.endingText(plan(number: 3, total: 4, seen: YearMonth(year: 2026, month: 10))) == "4/4 em novembro")
    }

    @Test func releasesText() {
        #expect(CardFormat.releasesText(plan(number: 3, total: 4, seen: YearMonth(year: 2026, month: 10))) == "libera em dez")
    }

    @Test func progressText() {
        let today = CardSamples.today
        #expect(CardFormat.progressText(plan(number: 3, total: 12, seen: YearMonth(year: 2026, month: 10)), today: today) == "3/12 · até jul/27")
        #expect(CardFormat.progressText(plan(number: 9, total: 10, seen: YearMonth(year: 2026, month: 10)), today: today) == "9/10 · até nov")
    }

    @Test func syncText() {
        let now = date(2026, 10, 22, 9, 30)
        #expect(CardFormat.syncText(date(2026, 10, 22, 6, 10), now: now, calendar: calendar) == "Atualizado hoje, 06:10")
        #expect(CardFormat.syncText(date(2026, 10, 21, 23, 0), now: now, calendar: calendar) == "Atualizado ontem")
        #expect(CardFormat.syncText(date(2026, 10, 12, 6, 10), now: now, calendar: calendar) == "Atualizado em 12/10")
        #expect(CardFormat.syncText(nil, now: now, calendar: calendar) == "Ainda não atualizado")
    }

    @Test func reviewTitle() {
        #expect(CardFormat.reviewTitle(1) == "1 recorrência para revisar")
        #expect(CardFormat.reviewTitle(3) == "3 recorrências para revisar")
    }

    @Test func candidateText() {
        #expect(CardFormat.candidateText(monthCount: 3, amount: 51) == "3 meses · ~R$\u{00A0}51,00")
    }

    @Test func connectionWarning() {
        let now = date(2026, 10, 22, 9, 30)
        let base = CardConnection(id: CardSamples.connection, itemID: "item", status: .active, lastSyncedAt: date(2026, 10, 12, 6, 10), lastError: nil)
        #expect(CardFormat.connectionWarning(base, nickname: "Nubank", now: now, calendar: calendar) == "Nubank sem atualizar desde 12/10")

        var fresh = base
        fresh.lastSyncedAt = date(2026, 10, 20, 6, 10)
        #expect(CardFormat.connectionWarning(fresh, nickname: "Nubank", now: now, calendar: calendar) == nil)

        var reconnect = fresh
        reconnect.status = .needsReconnect
        #expect(CardFormat.connectionWarning(reconnect, nickname: "Nubank", now: now, calendar: calendar) == "Nubank precisa reconectar")
    }

    @Test func statusTextDropsTimeAndFlagsReconnect() {
        let now = date(2026, 10, 22, 15)
        func connection(_ status: CardConnectionStatus, synced: Date?) -> CardConnection {
            CardConnection(id: UUID(), itemID: "i", status: status, lastSyncedAt: synced, lastError: nil)
        }
        #expect(CardFormat.statusText(connection(.active, synced: date(2026, 10, 22, 8, 30)), now: now, calendar: calendar) == "Atualizado hoje")
        #expect(CardFormat.statusText(connection(.active, synced: date(2026, 10, 21, 8)), now: now, calendar: calendar) == "Atualizado ontem")
        #expect(CardFormat.statusText(connection(.needsReconnect, synced: nil), now: now, calendar: calendar) == "Precisa reconectar")
    }

    @Test(arguments: [
        ("C6", "Mastercard Black", "4526", "C6 · Mastercard Black ····4526"),
        (nil, "Mastercard Black", "4526", "Mastercard Black ····4526"),
        ("C6", nil, "4526", "C6 ····4526"),
        (nil, nil, "4526", "····4526"),
        ("", "", "4526", "····4526"),
    ] as [(String?, String?, String, String)])
    func accountDetailTextOmitsMissingParts(institution: String?, brand: String?, digits: String, expected: String) {
        #expect(CardFormat.accountDetailText(institution: institution, brandLabel: brand, lastDigits: digits) == expected)
    }
}
