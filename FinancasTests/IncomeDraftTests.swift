import Foundation
import Testing
@testable import Financas

struct IncomeDraftTests {
    typealias S = IncomeSamples

    @Test func newHourlyStartsRateOneMonthBefore() throws {
        var draft = IncomeDraft(today: S.today)
        draft.kind = .hourly
        draft.name = "Por hora"
        draft.amount = 90
        draft.dayOfMonth = 15
        let (income, amount) = draft.build()
        #expect(income.kind == .hourly)
        #expect(income.hoursPerDay == 8)
        #expect(income.startMonth == S.month(2026, 10))
        #expect(income.oneOffDate == nil)
        let rate = try #require(amount)
        #expect(rate.validFrom == S.month(2026, 9))
        #expect(rate.amount == 90)
        #expect(rate.incomeID == income.id)
    }

    @Test func newFixedStartsAmountOnStartMonth() throws {
        var draft = IncomeDraft(today: S.today)
        draft.name = "Fixa"
        draft.amount = S.money("13020.04")
        let (income, amount) = draft.build()
        #expect(income.kind == .fixed)
        #expect(income.dayOfMonth == 1)
        #expect(income.hoursPerDay == nil)
        #expect(try #require(amount).validFrom == S.month(2026, 10))
    }

    @Test func oneOffHasNoAmountRecord() {
        var draft = IncomeDraft(today: S.today)
        draft.kind = .oneOff
        draft.name = "Bônus"
        draft.amount = 500
        let (income, amount) = draft.build()
        #expect(amount == nil)
        #expect(income.oneOffAmount == 500)
        #expect(income.oneOffDate == S.today)
        #expect(income.startMonth == nil)
        #expect(income.dayOfMonth == nil)
    }

    @Test func editWithSameAmountWritesNoNewRate() {
        let draft = IncomeDraft(income: S.hourly, snapshot: S.snapshot, today: S.today)
        #expect(draft.amount == 90)
        #expect(draft.incomeID == S.hourly.id)
        let (income, amount) = draft.build()
        #expect(income.id == S.hourly.id)
        #expect(amount == nil)
    }

    @Test func editWithNewAmountStartsOnChosenMonth() throws {
        var draft = IncomeDraft(income: S.hourly, snapshot: S.snapshot, today: S.today)
        draft.amount = 100
        draft.amountValidFrom = S.month(2026, 11)
        let amount = try #require(draft.build().1)
        #expect(amount.validFrom == S.month(2026, 11))
        #expect(amount.amount == 100)
    }

    @Test func retryingNewDraftKeepsSameID() {
        var draft = IncomeDraft(today: S.today)
        draft.name = "Fixa"
        draft.amount = 10
        let first = draft.build()
        let second = draft.build()
        #expect(draft.isNew)
        #expect(first.0.id == second.0.id)
        #expect(first.1?.id == second.1?.id)
    }

    @Test func validation() {
        var draft = IncomeDraft(today: S.today)
        draft.amount = 10
        #expect(draft.validationMessage == "Dê um nome para a receita.")

        draft.name = "  Fixa "
        draft.amount = 0
        #expect(draft.validationMessage == "Informe um valor maior que zero.")

        draft.amount = 10
        draft.endMonth = S.month(2026, 9)
        #expect(draft.validationMessage == "O mês de fim precisa ser depois do início.")

        draft.endMonth = nil
        draft.kind = .hourly
        draft.hoursPerDay = 0
        #expect(draft.validationMessage == "Informe as horas por dia.")

        draft.hoursPerDay = 8
        #expect(draft.validationMessage == nil)
        #expect(draft.build().0.name == "Fixa")
    }
}
