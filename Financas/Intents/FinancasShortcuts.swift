import AppIntents

struct FinancasShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LaunchSpendingIntent(),
            phrases: [
                "Lançar gasto no \(.applicationName)",
                "Registrar gasto no \(.applicationName)",
            ],
            shortTitle: "Lançar gasto",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenSuggestionReviewIntent(),
            phrases: [
                "Revisar compras no \(.applicationName)",
            ],
            shortTitle: "Revisar compras",
            systemImageName: "creditcard"
        )
    }
}
