import Foundation

struct InstallmentPlan: Hashable {
    let cardAccountID: UUID
    let name: String
    let purchaseDate: CalendarDay
    let installmentAmount: Decimal
    let totalInstallments: Int
    let lastSeenNumber: Int
    let lastSeenMonth: YearMonth

    var lastMonth: YearMonth {
        Self.advance(lastSeenMonth, by: totalInstallments - lastSeenNumber)
    }

    var releasesIn: YearMonth {
        lastMonth.next
    }

    private var firstMonth: YearMonth {
        Self.advance(lastSeenMonth, by: -(lastSeenNumber - 1))
    }

    func amount(in month: YearMonth) -> Decimal {
        month >= firstMonth && month <= lastMonth ? installmentAmount : 0
    }

    private static func advance(_ month: YearMonth, by count: Int) -> YearMonth {
        var result = month
        for _ in 0..<abs(count) {
            result = count >= 0 ? result.next : result.previous
        }
        return result
    }
}
