import Foundation

@MainActor
protocol SuggestionService {
    func load(since: Date) async throws(IncomeError) -> SuggestionSnapshot
    func report(_ purchase: SuggestionPurchase, merchantKey: String, device: SuggestionDevice) async throws(IncomeError) -> SuggestionReport
    func confirm(id: UUID, expenseID: UUID, spentOn: CalendarDay, autoLaunch: Bool?) async throws(IncomeError) -> SuggestionConfirmation
    func reopen(id: UUID) async throws(IncomeError) -> SpendingSuggestion
    func move(id: UUID, expenseID: UUID) async throws(IncomeError) -> SpendingSuggestion
    func dismiss(id: UUID) async throws(IncomeError)
}
