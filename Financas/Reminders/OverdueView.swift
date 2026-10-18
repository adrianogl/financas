import SwiftUI

struct OverdueView: View {
    @Environment(IncomeStore.self) private var store
    @Environment(ExpenseStore.self) private var expenseStore
    @State private var paying: ExpenseSheetTarget?
    @State private var editing: ExpenseDraft?

    var body: some View {
        let routes = shownIncomes.map(DetailRoute.init) + shownExpenses.filter { $0.part == nil }.map { DetailRoute($0.occurrence) }

        NavigationStack {
            ListDetailLayout(
                section: .overdue,
                title: "Atrasadas",
                add: nil,
                routes: routes,
                openRoutes: routes,
                month: store.selectedMonth,
                isLoaded: isLoaded,
                emptyText: nil
            ) { context in
                content(context)
            }
            .refreshable {
                async let incomes: Void = store.load()
                async let expenses: Void = expenseStore.load()
                _ = await (incomes, expenses)
            }
            .detailDestination()
        }
        .expenseFlow(paying: $paying, editing: $editing)
    }

    private var isLoaded: Bool {
        store.loadState == .loaded && expenseStore.loadState != .idle && expenseStore.loadState != .loading
    }

    private var shownIncomes: [IncomeOccurrence] {
        store.loadState == .loaded ? store.overdueOccurrences : []
    }

    private var shownExpenses: [ExpensePayable] {
        store.loadState == .loaded ? expenses : []
    }

    @ViewBuilder
    private func content(_ context: ListDetailContext) -> some View {
        if case .failed(let message) = expenseStore.loadState {
            expenseFailure(message)
        }
        IncomeLoadContent {
            if summary.isEmpty {
                emptyState
            } else {
                list(context)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nada atrasado")
                .font(.headline)
            Text("Quando uma receita ou conta passar da data sem ser marcada, ela aparece aqui.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func expenseFailure(_ message: String) -> some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Tentar de novo") {
                Task { await expenseStore.load() }
            }
            .buttonStyle(.glass)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private var expenses: [ExpensePayable] {
        expenseStore.loadState == .loaded ? expenseStore.overduePayables(today: store.today) : []
    }

    private var summary: OverdueSummary {
        OverdueSummary(incomes: store.overdueOccurrences, expenses: expenses)
    }

    @ViewBuilder
    private func list(_ context: ListDetailContext) -> some View {
        let summary = summary

        OverdueTotalCard(incoming: summary.incoming, outgoing: summary.outgoing)

        if summary.showsIncomes {
            section("Receitas") {
                DetailRowList(items: store.overdueOccurrences, context: context, route: DetailRoute.init) { occurrence, isSelected in
                    OverdueRow(occurrence: occurrence, today: store.today, isSelected: isSelected)
                }
            }
        }
        if summary.showsExpenses {
            section("Despesas") {
                OverdueExpenseList(payables: expenses, context: context, today: store.today) { payable in
                    paying = ExpenseSheetTarget(occurrence: payable.occurrence, mode: .payment, partID: payable.part?.part.id)
                }
            }
        }
    }

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            rows()
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }
}
