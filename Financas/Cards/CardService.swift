import Foundation

@MainActor
protocol CardService {
    func load(since: CalendarDay) async throws(IncomeError) -> CardSnapshot
    func save(_ recurrence: CardRecurrence) async throws(IncomeError)
    func rename(accountID: UUID, nickname: String) async throws(IncomeError)
    func sync() async throws(IncomeError)
    func connectToken(itemID: String?) async throws(IncomeError) -> String
    func register(itemID: String) async throws(IncomeError)
    func remove(connectionID: UUID) async throws(IncomeError)
}
