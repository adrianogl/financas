import Foundation

enum CardCommitment {
    static func months(plans: [InstallmentPlan], fixed: [FixedCharge], from start: YearMonth, count: Int) -> [CommitmentMonth] {
        let fixedTotal = fixed.map(\.amount).reduce(0, +)
        var month = start
        var result: [CommitmentMonth] = []
        for _ in 0..<max(count, 0) {
            let current = month
            result.append(CommitmentMonth(
                month: current,
                installments: plans.map { $0.amount(in: current) }.reduce(0, +),
                fixed: fixedTotal
            ))
            month = month.next
        }
        return result
    }

    static func ending(_ plans: [InstallmentPlan], today: CalendarDay) -> [InstallmentPlan] {
        var limit = today.yearMonth
        for _ in 0..<CardConstants.endingWindowMonths {
            limit = limit.next
        }
        return plans
            .filter { $0.lastMonth >= today.yearMonth && $0.lastMonth <= limit }
            .sorted { ($0.lastMonth, $0.name) < ($1.lastMonth, $1.name) }
    }
}
