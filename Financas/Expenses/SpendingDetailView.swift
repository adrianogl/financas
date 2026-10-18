import SwiftUI

struct SpendingDetailView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    let spendingID: String
    let month: YearMonth
    @State private var editing: ExpenseDraft?
    @State private var entrySheet: SpendingEntryTarget?

    var body: some View {
        DetailScaffold(item: spending) { spending in
            content(spending)
        }
        .expenseFlow(paying: .constant(nil), editing: $editing)
        .sheet(item: $entrySheet) { target in
            SpendingEntrySheet(draft: target.draft, entry: target.entry)
                .presentationEnabled()
        }
    }

    private var today: CalendarDay {
        incomeStore.today
    }

    private var spending: SpendingMonth? {
        store.spendings(in: month, today: today).first { $0.id == spendingID }
    }

    private func content(_ spending: SpendingMonth) -> some View {
        let monthName = IncomeFormat.monthName(spending.month)
        let history = store.spendingHistory(of: spending.expense, through: spending.month, today: today)
        return VStack(alignment: .leading, spacing: 18) {
            DetailHeader(rule: ExpenseFormat.spendingHeaderRule(spending.expected), title: spending.expense.name) {
                editing = ExpenseDraft(expense: spending.expense, snapshot: store.snapshot, today: today)
            }
            SpendingMonthCard(spending: spending, today: today)
            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, 6)
            }
            if spending.month <= today.yearMonth {
                GlassPrimaryButton(title: "Adicionar gasto") {
                    entrySheet = SpendingEntryTarget(draft: ExpenseEntryDraft(expense: spending.expense, month: spending.month, today: today), entry: nil)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Lançamentos de \(monthName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                if spending.entries.isEmpty {
                    Text("Nenhum gasto lançado em \(monthName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    SpendingEntryList(entries: spending.entries, edit: { edit($0, of: spending.expense) }, delete: delete)
                }
            }
            if !history.isEmpty {
                SpendingHistoryChart(history: history, selected: spending.month)
            }
        }
    }

    private func edit(_ entry: ExpenseEntry, of expense: Expense) {
        entrySheet = SpendingEntryTarget(draft: ExpenseEntryDraft(entry: entry, expense: expense, today: today), entry: entry)
    }

    private func delete(_ entry: ExpenseEntry) {
        Task {
            _ = await store.deleteEntry(entry)
        }
    }
}
