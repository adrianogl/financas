import Foundation
import Testing
@testable import Financas

struct IncomeFormatTests {
    typealias S = IncomeSamples

    @Test func monthTitle() {
        #expect(IncomeFormat.monthTitle(S.month(2026, 10)) == "Outubro de 2026")
        #expect(IncomeFormat.monthName(S.month(2026, 9)) == "setembro")
    }

    @Test func shortDate() {
        #expect(IncomeFormat.shortDate(S.day(2026, 10, 15)) == "qui, 15 out")
        #expect(IncomeFormat.shortDate(S.day(2026, 11, 3)) == "ter, 3 nov")
    }

    @Test func rules() {
        #expect(IncomeFormat.rule(for: S.fixed, rate: S.money("13020.04"), nonBusinessDay: .next) == "Todo dia 1 · próximo dia útil")
        #expect(IncomeFormat.rule(for: S.hourly, rate: 90, nonBusinessDay: .next) == "Todo dia 15 · R$\u{00A0}90/h · 8h/dia")
    }

    @Test func ruleTextFollowsSetting() {
        #expect(IncomeFormat.rule(for: S.fixed, rate: nil, nonBusinessDay: .next) == "Todo dia 1 · próximo dia útil")
        #expect(IncomeFormat.rule(for: S.fixed, rate: nil, nonBusinessDay: .previous) == "Todo dia 1 · dia útil anterior")
        #expect(IncomeFormat.rule(for: S.fixed, rate: nil, nonBusinessDay: .keep) == "Todo dia 1")
        #expect(IncomeFormat.rule(for: S.hourly, rate: 90, nonBusinessDay: .previous) == "Todo dia 15 · R$\u{00A0}90/h · 8h/dia")
    }

    @Test func formHintFollowsSetting() {
        #expect(NonBusinessDayRule.next.formHint(hourly: false) == "Se o dia não for útil, cai no próximo dia útil.")
        #expect(NonBusinessDayRule.previous.formHint(hourly: false) == "Se o dia não for útil, cai no dia útil anterior.")
        #expect(NonBusinessDayRule.keep.formHint(hourly: false) == "A data fica no dia escolhido, mesmo se não for útil.")
        #expect(NonBusinessDayRule.keep.formHint(hourly: true) == "A data fica no dia escolhido, mesmo se não for útil. O pagamento cobre os dias úteis do mês anterior.")
    }

    @Test func occurrenceTitle() throws {
        let hourly = try #require(IncomeSchedule.occurrence(of: S.hourly, in: S.month(2026, 10), snapshot: S.snapshot, today: S.today))
        let fixed = try #require(IncomeSchedule.occurrence(of: S.fixed, in: S.month(2026, 10), snapshot: S.snapshot, today: S.today))
        #expect(IncomeFormat.occurrenceTitle(hourly) == "Por hora · setembro")
        #expect(IncomeFormat.occurrenceTitle(fixed) == "Fixa")
    }

    @Test func currency() {
        #expect(IncomeFormat.currency(S.money("13020.04")) == "R$\u{00A0}13.020,04")
        #expect(IncomeFormat.currency(15120) == "R$\u{00A0}15.120,00")
    }
}
