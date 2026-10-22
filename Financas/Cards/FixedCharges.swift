import Foundation

enum FixedCharges {
    static func charges(from transactions: [CardTransaction], recurrences: [CardRecurrence], today: CalendarDay) -> [FixedCharge] {
        recurrences
            .filter { $0.status == .confirmed }
            .compactMap { charge(for: $0, in: transactions, today: today) }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    private static func charge(for recurrence: CardRecurrence, in transactions: [CardTransaction], today: CalendarDay) -> FixedCharge? {
        let last = transactions
            .filter {
                $0.cardAccountID == recurrence.cardAccountID
                    && $0.type == .debit
                    && !$0.isPending
                    && ($0.totalInstallments ?? 0) < 2
                    && MerchantKey.make($0.description) == recurrence.merchantKey
            }
            .max { $0.date < $1.date }
        guard let last else { return nil }
        return FixedCharge(
            recurrence: recurrence,
            name: last.description,
            amount: last.amount,
            lastChargedOn: last.date,
            isStale: last.date.days(until: today) > CardConstants.fixedChargeStaleDays
        )
    }
}
