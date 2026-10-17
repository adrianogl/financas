import Foundation

struct HomeEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let kind: IncomeKind
    let receivedOn: CalendarDay
    let amount: Decimal
}
