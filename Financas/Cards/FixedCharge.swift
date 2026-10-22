import Foundation

struct FixedCharge: Hashable, Identifiable, Sendable {
    let recurrence: CardRecurrence
    let name: String
    let amount: Decimal
    let lastChargedOn: CalendarDay
    let isStale: Bool

    var id: UUID { recurrence.id }
}
