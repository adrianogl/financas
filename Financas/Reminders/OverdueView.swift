import SwiftUI

struct OverdueView: View {
    @Environment(IncomeStore.self) private var store
    @Environment(ExpenseStore.self) private var expenseStore
    @State private var editing: IncomeDraft?
    @State private var receiving: IncomeOccurrence?
    @State private var editingExpense: ExpenseDraft?
    @State private var paying: ExpenseSheetTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Atrasadas")
            .refreshable {
                async let incomes: Void = store.load()
                async let expenses: Void = expenseStore.load()
                _ = await (incomes, expenses)
            }
            .incomeReceiptFlow(receiving: $receiving, editing: $editing)
            .expenseFlow(paying: $paying, editing: $editingExpense)
        }
    }

    private var content: some View {
        IncomeLoadContent {
            if summary.isEmpty {
                emptyState
            } else {
                list
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

    private var expenses: [ExpenseOccurrence] {
        expenseStore.loadState == .loaded ? expenseStore.overdueOccurrences(today: store.today) : []
    }

    private var summary: OverdueSummary {
        OverdueSummary(incomes: store.overdueOccurrences, expenses: expenses)
    }

    @ViewBuilder
    private var list: some View {
        let incomes = store.overdueOccurrences
        let expenses = expenses
        let summary = summary

        OverdueTotalCard(incoming: summary.incoming, outgoing: summary.outgoing)

        if summary.showsIncomes {
            section("Receitas", items: incomes) { occurrence in
                Button {
                    receiving = occurrence
                } label: {
                    OverdueRow(occurrence: occurrence, today: store.today)
                }
                .buttonStyle(.plain)
            }
        }
        if summary.showsExpenses {
            section("Despesas", items: expenses) { occurrence in
                Button {
                    paying = ExpenseSheetTarget(occurrence: occurrence, mode: .payment)
                } label: {
                    OverdueExpenseRow(occurrence: occurrence, today: store.today)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func section<Item: Identifiable, Row: View>(
        _ title: String,
        items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View where Item.ID == String {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    row(item)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }
}
