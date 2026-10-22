import Foundation

enum RecurrenceDetector {
    private struct GroupKey: Hashable {
        let cardAccountID: UUID
        let merchantKey: String
    }

    static func candidates(from transactions: [CardTransaction], decisions: [CardRecurrence], today: CalendarDay) -> [RecurrenceCandidate] {
        let windowStart = YearMonth(year: today.year - CardConstants.recurrenceWindowMonths / 12, month: today.month).day(today.day)
        let eligible = transactions.filter {
            $0.type == .debit && !$0.isPending && ($0.totalInstallments ?? 0) < 2 && $0.date >= windowStart && $0.date <= today
        }
        let grouped = Dictionary(grouping: eligible) {
            GroupKey(cardAccountID: $0.cardAccountID, merchantKey: MerchantKey.make($0.description))
        }
        return grouped
            .compactMap { key, charges in candidate(key: key, charges: charges, decisions: decisions) }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }
    }

    private static func candidate(key: GroupKey, charges: [CardTransaction], decisions: [CardRecurrence]) -> RecurrenceCandidate? {
        let months = Set(charges.map { $0.date.yearMonth })
        guard months.count >= CardConstants.recurrenceMinimumMonths else { return nil }
        let amounts = charges.map(\.amount)
        let typical = median(amounts)
        guard typical > 0 else { return nil }
        let tolerance = typical * CardConstants.recurrenceAmountTolerance
        guard amounts.allSatisfy({ abs($0 - typical) <= tolerance }) else { return nil }
        let decision = decisions.first { $0.cardAccountID == key.cardAccountID && $0.merchantKey == key.merchantKey }
        var chargedAfterEnd = false
        switch decision?.status {
        case .none:
            break
        case .confirmed, .dismissed:
            return nil
        case .ended:
            guard let endedOn = decision?.endedOn, charges.contains(where: { $0.date > endedOn }) else { return nil }
            chargedAfterEnd = true
        }
        guard let latest = charges.max(by: { $0.date < $1.date }) else { return nil }
        return RecurrenceCandidate(
            cardAccountID: key.cardAccountID,
            merchantKey: key.merchantKey,
            name: latest.description,
            monthCount: months.count,
            typicalAmount: typical,
            chargedAfterEnd: chargedAfterEnd
        )
    }

    private static func median(_ values: [Decimal]) -> Decimal {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
}
