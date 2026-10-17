import Foundation

struct HomeEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let kind: HomeEntryKind
    let date: CalendarDay
    let amount: Decimal
}
