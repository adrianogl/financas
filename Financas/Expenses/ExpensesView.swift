import SwiftUI

struct ExpensesView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @State private var editing: ExpenseDraft?
    @State private var paying: ExpenseSheetTarget?

    var body: some View {
        @Bindable var incomeStore = incomeStore

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonthPicker(month: $incomeStore.selectedMonth)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Despesas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nova despesa", systemImage: "plus") {
                        editing = ExpenseDraft(today: incomeStore.today)
                    }
                }
            }
            .refreshable { await store.load() }
            .expenseFlow(paying: $paying, editing: $editing)
        }
    }

    private var content: some View {
        ExpenseLoadContent {
            if store.snapshot.expenses.isEmpty {
                emptyState
            } else {
                monthContent
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
            GlassPrimaryButton(title: "Cadastrar despesa") {
                editing = ExpenseDraft(today: incomeStore.today)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var monthContent: some View {
        let today = incomeStore.today
        let month = incomeStore.selectedMonth
        let occurrences = store.occurrences(in: month, today: today)
        let open = occurrences.filter { $0.status != .paid }.sorted(by: openOrder)
        let paid = occurrences.filter { $0.status == .paid }
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
            section("A pagar", occurrences: open)
        }
        if !paid.isEmpty {
            section("Pagas", occurrences: paid)
        }
        if occurrences.isEmpty {
            Text("Nenhuma despesa prevista para \(IncomeFormat.monthName(month)).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        if month >= today.yearMonth, !active.isEmpty || !ended.isEmpty {
            registered(active: active, ended: ended)
        }
    }

    private func section(_ title: String, occurrences: [ExpenseOccurrence]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(occurrences) { occurrence in
                    Button {
                        paying = ExpenseSheetTarget(occurrence: occurrence, mode: nil)
                    } label: {
                        ExpenseOccurrenceRow(occurrence: occurrence, today: incomeStore.today)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Editar despesa", systemImage: "pencil") {
                            edit(occurrence.expense)
                        }
                    }
                    if occurrence.id != occurrences.last?.id {
                        Divider()
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
                            estimate: store.currentEstimate(for: expense, today: incomeStore.today)
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

    private func openOrder(_ lhs: ExpenseOccurrence, _ rhs: ExpenseOccurrence) -> Bool {
        let lhsOverdue = lhs.status == .overdue
        let rhsOverdue = rhs.status == .overdue
        if lhsOverdue != rhsOverdue {
            return lhsOverdue
        }
        if lhsOverdue, lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return (lhs.dueDate, lhs.expense.name) < (rhs.dueDate, rhs.expense.name)
    }

    private func edit(_ expense: Expense) {
        editing = ExpenseDraft(expense: expense, snapshot: store.snapshot, today: incomeStore.today)
    }
}
