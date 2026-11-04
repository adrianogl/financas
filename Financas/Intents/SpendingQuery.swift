import AppIntents

struct SpendingQuery: EntityStringQuery {
    @Dependency private var store: ExpenseStore

    @MainActor
    func entities(for identifiers: [SpendingEntity.ID]) async throws -> [SpendingEntity] {
        try await SpendingCatalog.entities(store: store).filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SpendingEntity] {
        try await SpendingCatalog.entities(store: store)
    }

    @MainActor
    func entities(matching string: String) async throws -> [SpendingEntity] {
        try await SpendingCatalog.entities(store: store).filter { QuickSpending.matches($0.name, query: string) }
    }
}
