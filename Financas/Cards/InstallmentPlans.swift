import Foundation

enum InstallmentPlans {
    private struct PurchaseKey: Hashable {
        let cardAccountID: UUID
        let purchaseDate: CalendarDay
        let totalInstallments: Int
        let merchant: String
    }

    static func plans(from transactions: [CardTransaction], today: CalendarDay) -> [InstallmentPlan] {
        let grouped = Dictionary(grouping: transactions.compactMap(candidate)) { $0.key }
        return grouped.values
            .compactMap { plan(from: $0.map(\.transaction), today: today) }
            .sorted { ($0.lastMonth, $0.name) < ($1.lastMonth, $1.name) }
    }

    private static func candidate(_ transaction: CardTransaction) -> (key: PurchaseKey, transaction: CardTransaction)? {
        guard transaction.type == .debit,
              let total = transaction.totalInstallments, total >= 2,
              transaction.installmentNumber != nil,
              let purchaseDate = transaction.purchaseDate else { return nil }
        let key = PurchaseKey(
            cardAccountID: transaction.cardAccountID,
            purchaseDate: purchaseDate,
            totalInstallments: total,
            merchant: MerchantKey.make(transaction.description)
        )
        return (key, transaction)
    }

    private static func plan(from transactions: [CardTransaction], today: CalendarDay) -> InstallmentPlan? {
        let byNumber = Dictionary(grouping: transactions) { $0.installmentNumber ?? 0 }
            .compactMapValues { $0.max { $0.date < $1.date } }
        guard let last = byNumber.values.max(by: { ($0.installmentNumber ?? 0, $0.date) < ($1.installmentNumber ?? 0, $1.date) }),
              let number = last.installmentNumber,
              let total = last.totalInstallments,
              let purchaseDate = last.purchaseDate else { return nil }
        let seenMonth = last.date.yearMonth
        if number < total, today.yearMonth >= dropMonth(after: seenMonth) { return nil }
        return InstallmentPlan(
            cardAccountID: last.cardAccountID,
            name: MerchantKey.stripInstallment(last.description),
            purchaseDate: purchaseDate,
            installmentAmount: last.amount,
            totalInstallments: total,
            lastSeenNumber: number,
            lastSeenMonth: seenMonth
        )
    }

    private static func dropMonth(after month: YearMonth) -> YearMonth {
        (0..<CardConstants.installmentDropAfterMonths).reduce(month) { current, _ in current.next }
    }
}
