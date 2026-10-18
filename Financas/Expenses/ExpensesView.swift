import SwiftUI

struct ExpensesView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @State private var editing: ExpenseDraft?

    var body: some View {
        @Bindable var incomeStore = incomeStore
        let list = monthList
        let open = list.open
        let paid = list.paid

        NavigationStack {
            ListDetailLayout(
                section: .expenses,
                title: "Despesas",
                add: SectionAddAction(title: "Nova despesa", action: create),
                routes: (open + paid).map(DetailRoute.init),
                openRoutes: open.map(DetailRoute.init),
                month: incomeStore.selectedMonth,
                isLoaded: store.loadState == .loaded,
                emptyText: hasMonthList ? emptyMonthText : nil
            ) { context in
                MonthPicker(month: $incomeStore.selectedMonth)
                content(context, open: open, paid: paid)
            }
            .refreshable { await store.load() }
            .expenseFlow(paying: .constant(nil), editing: $editing)
            .detailDestination()
        }
    }

    private var hasMonthList: Bool {
        store.loadState == .loaded && !store.snapshot.expenses.isEmpty
    }

    private var monthOccurrences: [ExpenseOccurrence] {
        hasMonthList ? store.occurrences(in: incomeStore.selectedMonth, today: incomeStore.today) : []
    }

    private var monthList: ExpenseMonthList {
        ExpenseMonthList(occurrences: monthOccurrences)
    }

    private var emptyMonthText: String {
        "Nenhuma despesa prevista para \(IncomeFormat.monthName(incomeStore.selectedMonth))."
    }

    private func content(_ context: ListDetailContext, open: [ExpenseOccurrence], paid: [ExpenseOccurrence]) -> some View {
        ExpenseLoadContent {
            if store.snapshot.expenses.isEmpty {
                emptyState
            } else {
                monthContent(context, open: open, paid: paid)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nenhuma despesa cadastrada")
                .font(.headline)
            Text("Cadastre suas contas fixas para ver quanto falta pagar no mês.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            GlassPrimaryButton(title: "Cadastrar despesa", action: create)
                .padding(.top, 6)
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private func monthContent(_ context: ListDetailContext, open: [ExpenseOccurrence], paid: [ExpenseOccurrence]) -> some View {
        let today = incomeStore.today
        let month = incomeStore.selectedMonth
        let active = store.activeExpenses(today: today)
        let ended = store.endedExpenses(today: today)

        ExpenseMonthSummaryCard(summary: store.summary(for: month, today: today))

        if let message = store.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .padding(.horizontal, 6)
        }

        if !open.isEmpty {
            section("A pagar", occurrences: open, context: context)
        }
        if !paid.isEmpty {
            section("Pagas", occurrences: paid, context: context)
        }
        if open.isEmpty && paid.isEmpty {
            Text(emptyMonthText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        if month >= today.yearMonth, !active.isEmpty || !ended.isEmpty {
            registered(active: active, ended: ended)
        }
    }

    private func section(_ title: String, occurrences: [ExpenseOccurrence], context: ListDetailContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            DetailRowList(items: occurrences, context: context, route: DetailRoute.init) { occurrence, isSelected in
                ExpenseOccurrenceRow(occurrence: occurrence, today: incomeStore.today, isSelected: isSelected)
                    .contextMenu {
                        Button("Editar despesa", systemImage: "pencil") {
                            edit(occurrence.expense)
                        }
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    private func registered(active: [Expense], ended: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Cadastradas")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(active) { expense in
                    Button {
                        edit(expense)
                    } label: {
                        ExpenseRow(
                            expense: expense,
                            term: store.currentTerm(for: expense, today: incomeStore.today),
                            estimate: store.currentEstimate(for: expense, today: incomeStore.today),
                            partCount: store.currentPartCount(for: expense, today: incomeStore.today)
                        )
                    }
                    .buttonStyle(.plain)
                    if expense.id != active.last?.id || !ended.isEmpty {
                        Divider()
                    }
                }
                if !ended.isEmpty {
                    NavigationLink {
                        EndedExpensesView(edit: edit)
                    } label: {
                        HStack {
                            Text("Encerradas")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(ended.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
    }

    private func create() {
        editing = ExpenseDraft(today: incomeStore.today)
    }

    private func edit(_ expense: Expense) {
        editing = ExpenseDraft(expense: expense, snapshot: store.snapshot, today: incomeStore.today)
    }
}
