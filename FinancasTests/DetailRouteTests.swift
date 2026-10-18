import Foundation
import Testing
@testable import Financas

struct DetailRouteTests {
    typealias S = ExpenseSamples

    @Test func spendingRouteSectionAndID() {
        let abastecimento = Expense(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
            name: "Abastecimento",
            startMonth: S.month(2026, 10),
            kind: .spending
        )
        let spending = SpendingMonth(
            expense: abastecimento,
            month: S.month(2026, 10),
            expected: 600,
            spent: 420,
            remaining: 180,
            entries: []
        )
        let route = DetailRoute(spending)
        #expect(route == .spending(id: spending.id, month: S.month(2026, 10)))
        #expect(route.section == .expenses)
        #expect(route.occurrenceID == spending.id)
    }
}
