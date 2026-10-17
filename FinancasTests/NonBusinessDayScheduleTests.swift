import Foundation
import Testing
@testable import Financas

@MainActor
struct NonBusinessDayScheduleTests {
    typealias S = IncomeSamples

    private func snapshot(_ rule: NonBusinessDayRule, incomes: [Income] = [S.fixed, S.hourly], amounts: [IncomeAmount] = [S.fixedAmount, S.hourlyRate]) -> IncomeSnapshot {
        var snapshot = IncomeSnapshot(incomes: incomes, amounts: amounts, receipts: [])
        snapshot.settings.nonBusinessDay = rule
        return snapshot
    }

    private func makeStore(_ snapshot: IncomeSnapshot, today: CalendarDay) async -> IncomeStore {
        let store = IncomeStore(service: FakeIncomeService(snapshot: snapshot), today: { today })
        await store.load()
        return store
    }

    private func novemberFixedID() -> String {
        "\(S.fixed.id)-2026-11"
    }

    @Test func previousRuleCarriesNextMonthOverdueIntoCurrentMonth() async {
        let store = await makeStore(snapshot(.previous), today: S.day(2026, 10, 31))
        let overdue = store.overdueOccurrences
        #expect(overdue.contains { $0.id == novemberFixedID() && $0.dueDate == S.day(2026, 10, 30) })
        #expect(Set(overdue.map(\.id)).count == overdue.count)
        #expect(store.summary(for: S.month(2026, 10)).overdueCount == 3)
        #expect(store.occurrences(in: S.month(2026, 10)).contains { $0.id == novemberFixedID() })
        #expect(store.occurrences(in: S.month(2026, 11)).contains { $0.id == novemberFixedID() })
    }

    @Test func nextRuleDoesNotCarryNextMonth() async {
        let store = await makeStore(snapshot(.next), today: S.day(2026, 10, 31))
        #expect(!store.overdueOccurrences.contains { $0.id == novemberFixedID() })
        #expect(store.summary(for: S.month(2026, 10)).overdueCount == 2)
    }

    @Test func previousRuleDueTodayEntersDueItems() async throws {
        let store = await makeStore(snapshot(.previous), today: S.day(2026, 10, 30))
        let item = try #require(store.dueItems?.first { $0.id == novemberFixedID() })
        #expect(item.dueDate == S.day(2026, 10, 30))
    }

    @Test func ruleDoesNotChangeOneOffDate() throws {
        let oneOff = Income(id: UUID(), name: "Bônus", kind: .oneOff, oneOffDate: S.day(2026, 10, 17), oneOffAmount: 500)
        for rule in NonBusinessDayRule.allCases {
            let occurrence = try #require(IncomeSchedule.occurrence(of: oneOff, in: S.month(2026, 10), snapshot: snapshot(rule, incomes: [oneOff], amounts: []), today: S.today))
            #expect(occurrence.dueDate == S.day(2026, 10, 17))
        }
    }

    @Test func ruleDoesNotChangeHourlyAmount() throws {
        let amounts = try NonBusinessDayRule.allCases.map { rule in
            try #require(IncomeSchedule.occurrence(of: S.hourly, in: S.month(2026, 11), snapshot: snapshot(rule), today: S.today)).expectedAmount
        }
        #expect(Set(amounts).count == 1)
    }

    @Test func hourlyFollowsRule() throws {
        let previous = try #require(IncomeSchedule.occurrence(of: S.hourly, in: S.month(2026, 11), snapshot: snapshot(.previous), today: S.today))
        let keep = try #require(IncomeSchedule.occurrence(of: S.hourly, in: S.month(2026, 11), snapshot: snapshot(.keep), today: S.today))
        #expect(previous.dueDate == S.day(2026, 11, 13))
        #expect(keep.dueDate == S.day(2026, 11, 15))
    }

    @Test func standardSettingsKeepCurrentDates() throws {
        let fixed = try #require(IncomeSchedule.occurrence(of: S.fixed, in: S.month(2026, 11), snapshot: S.snapshot, today: S.today))
        let hourly = try #require(IncomeSchedule.occurrence(of: S.hourly, in: S.month(2026, 11), snapshot: S.snapshot, today: S.today))
        #expect(fixed.dueDate == S.day(2026, 11, 3))
        #expect(hourly.dueDate == S.day(2026, 11, 16))
    }

    @Test func previousRuleShowsNextMonthDueTodayInCurrentMonth() async {
        let store = await makeStore(snapshot(.previous), today: S.day(2026, 10, 30))
        #expect(store.occurrences(in: S.month(2026, 10)).contains { $0.id == novemberFixedID() && $0.status == .pending })
        let baseline = await makeStore(snapshot(.next), today: S.day(2026, 10, 30))
        let difference = store.summary(for: S.month(2026, 10)).remaining - baseline.summary(for: S.month(2026, 10)).remaining
        #expect(difference == S.money("13020.04"))
    }
}
