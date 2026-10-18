import Foundation
import Testing
@testable import Financas

struct MonthListOrderTests {
    private func income(_ name: String, due: Int, status: OccurrenceStatus) -> IncomeOccurrence {
        IncomeOccurrence(
            income: Income(id: UUID(), name: name, kind: .fixed, dayOfMonth: due, startMonth: IncomeSamples.month(2026, 10)),
            month: IncomeSamples.month(2026, 10),
            referenceMonth: nil,
            dueDate: IncomeSamples.day(2026, 10, due),
            expectedAmount: 100,
            businessDays: nil,
            hourlyRate: nil,
            receipt: nil,
            status: status
        )
    }

    @Test func incomesPutOverdueFirstThenPendingByDateThenReceived() {
        let list = IncomeMonthList(occurrences: [
            income("Salário", due: 5, status: .received),
            income("Pensão", due: 25, status: .pending),
            income("Bônus", due: 20, status: .pending),
            income("Freela", due: 12, status: .overdue),
        ])
        #expect(list.open.map(\.income.name) == ["Freela", "Bônus", "Pensão"])
        #expect(list.received.map(\.income.name) == ["Salário"])
        #expect(list.all.map(\.income.name) == ["Freela", "Bônus", "Pensão", "Salário"])
    }

    @Test func expensesPutOverdueFirstThenPendingThenPaid() {
        let october = ExpenseSamples.month(2026, 10)
        var snapshot = ExpenseSamples.snapshot
        snapshot.bills = [ExpenseSamples.paid(ExpenseSamples.condominio, october, 1150, on: ExpenseSamples.day(2026, 10, 9))]
        let occurrences = ExpenseSchedule.occurrences(in: october, snapshot: snapshot, today: ExpenseSamples.today)

        let list = ExpenseMonthList(occurrences: occurrences)

        #expect(list.open.map(\.expense.name) == ["Luz", "Internet"])
        #expect(list.paid.map(\.expense.name) == ["Condomínio"])
        #expect(list.all.map(\.expense.name) == ["Luz", "Internet", "Condomínio"])
    }
}
