import Foundation

@MainActor
protocol ExpenseService {
    func load() async throws(IncomeError) -> ExpenseSnapshot
    func save(
        _ expense: Expense,
        term: ExpenseTerm?,
        parts: [ExpensePart],
        partTerms: [ExpensePartTerm]
    ) async throws(IncomeError)
    func delete(expenseID: UUID) async throws(IncomeError)
    func save(_ bill: ExpenseBill) async throws(IncomeError)
    func deleteBill(id: UUID) async throws(IncomeError)
    func save(_ entry: ExpenseEntry) async throws(IncomeError)
    func deleteEntry(id: UUID) async throws(IncomeError)
}
