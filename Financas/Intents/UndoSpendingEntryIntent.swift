import AppIntents

struct UndoSpendingEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Desfazer lançamento"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Lançamento")
    var entryID: String

    @Dependency private var store: ExpenseStore

    init() {}

    init(entryID: UUID) {
        self.entryID = entryID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await SpendingCatalog.loaded(store)
        guard let id = UUID(uuidString: entryID), let entry = store.snapshot.entries.first(where: { $0.id == id }) else {
            return .result(dialog: "\(SpendingIntentConstants.entryGoneMessage)")
        }
        guard await store.deleteEntry(entry) else {
            throw SpendingIntentError.saveFailed(store.errorMessage ?? "")
        }
        return .result(dialog: "\(SpendingIntentConstants.undoneMessage)")
    }
}
