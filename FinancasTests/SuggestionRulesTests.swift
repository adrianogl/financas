import Foundation
import Testing
@testable import Financas

struct SuggestionRulesTests {
    typealias S = ExpenseSamples

    private let padaria = Expense(id: UUID(), name: "Padaria", startMonth: S.month(2026, 10), kind: .spending)
    private let mercado = Expense(id: UUID(), name: "Mercado", startMonth: S.month(2026, 10), kind: .spending)
    private let avulsos = Expense(id: UUID(), name: "Avulsos", startMonth: S.month(2026, 10), kind: .spending)

    private func suggestion(amount: String, on day: CalendarDay, status: SpendingSuggestionStatus = .pending, expenseID: UUID? = nil) -> SpendingSuggestion {
        SpendingSuggestion(
            id: UUID(),
            merchant: "MAGAZINE ELETRO",
            merchantKey: "MAGAZINE ELETRO",
            card: "Nubank",
            amount: S.money(amount),
            occurredAt: day.date(),
            reporterDevices: [UUID()],
            firstDeviceName: "iPhone",
            status: status,
            expenseID: expenseID
        )
    }

    private func installment(_ amount: String, number: Int, of total: Int, purchasedOn: CalendarDay) -> CardTransaction {
        CardTransaction(
            id: UUID().uuidString,
            cardAccountID: CardSamples.c6.id,
            date: purchasedOn,
            description: "MAGAZINE ELETRO \(number)/\(total)",
            amount: S.money(amount),
            type: .debit,
            isPending: false,
            installmentNumber: number,
            totalInstallments: total,
            purchaseDate: purchasedOn
        )
    }

    @Test func fallsBackToTheLastUsedSpendingWithoutRule() {
        let entries = [ExpenseEntry(id: UUID(), expenseID: mercado.id, spentOn: S.day(2026, 11, 1), amount: 10)]

        let expense = SuggestedCategory.expense(for: "PADARIA", rules: [], options: [padaria, mercado], entries: entries)

        #expect(expense == mercado)
    }

    @Test func ignoresARuleWhoseSpendingIsNotAnOption() {
        let rule = MerchantSpendingRule(id: UUID(), merchantKey: "PADARIA", expenseID: UUID(), autoLaunch: true)

        #expect(SuggestedCategory.expense(for: "PADARIA", rules: [rule], options: [padaria, mercado], entries: []) == padaria)
        #expect(SuggestedCategory.autoLaunchExpense(for: "PADARIA", rules: [rule], options: [padaria, mercado]) == nil)
    }

    @Test func alternativesSkipTheSuggestedSpending() {
        #expect(SuggestedCategory.alternatives(to: mercado, ranked: [padaria, mercado, avulsos]) == [padaria, avulsos])
    }

    @Test func countsOnlyConfirmedSuggestionsOfTheSameSpending() {
        let suggestions = [
            suggestion(amount: "10", on: S.day(2026, 11, 1), status: .confirmed, expenseID: padaria.id),
            suggestion(amount: "10", on: S.day(2026, 11, 2), status: .confirmed, expenseID: padaria.id),
            suggestion(amount: "10", on: S.day(2026, 11, 3), status: .confirmed, expenseID: mercado.id),
            suggestion(amount: "10", on: S.day(2026, 11, 4)),
        ]

        #expect(SuggestedCategory.confirmedCount(merchantKey: "MAGAZINE ELETRO", expenseID: padaria.id, suggestions: suggestions) == 2)
    }

    @Test func findsTheInstallmentPlanOfTheSamePurchase() {
        let purchase = suggestion(amount: "1200.00", on: S.day(2026, 11, 3))
        let first = installment("120.00", number: 1, of: 10, purchasedOn: S.day(2026, 11, 2))

        #expect(CardOverlap.installment(for: purchase, in: [first]) == first)
    }

    @Test func toleratesRoundingOfTheInstallments() {
        let purchase = suggestion(amount: "100.00", on: S.day(2026, 11, 3))
        let first = installment("33.34", number: 1, of: 3, purchasedOn: S.day(2026, 11, 3))

        #expect(CardOverlap.installment(for: purchase, in: [first]) == first)
    }

    @Test func ignoresInstallmentsOfOtherAmountsOrDates() {
        let purchase = suggestion(amount: "1200.00", on: S.day(2026, 11, 3))
        let otherAmount = installment("150.00", number: 1, of: 10, purchasedOn: S.day(2026, 11, 3))
        let tooOld = installment("120.00", number: 1, of: 10, purchasedOn: S.day(2026, 10, 20))
        let single = installment("1200.00", number: 1, of: 1, purchasedOn: S.day(2026, 11, 3))

        #expect(CardOverlap.installment(for: purchase, in: [otherAmount, tooOld, single]) == nil)
    }
}
