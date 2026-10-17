import Foundation

@MainActor
protocol IncomeService {
    func load() async throws(IncomeError) -> IncomeSnapshot
    func save(_ income: Income, amount: IncomeAmount?) async throws(IncomeError)
    func delete(incomeID: UUID) async throws(IncomeError)
    func save(_ receipt: IncomeReceipt) async throws(IncomeError)
    func deleteReceipt(id: UUID) async throws(IncomeError)
    func saveSettings(_ settings: AccountSettings, previous: AccountSettings) async throws(IncomeError)
}
