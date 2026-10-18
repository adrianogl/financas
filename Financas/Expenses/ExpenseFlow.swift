import SwiftUI

struct ExpenseFlow: ViewModifier {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @Binding var paying: ExpenseSheetTarget?
    @Binding var editing: ExpenseDraft?
    @State private var pendingEdit: Expense?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isEditing) {
                if let draft = editing {
                    ExpenseFormView(
                        draft: draft,
                        expense: store.snapshot.expenses.first { $0.id == draft.expenseID },
                        today: incomeStore.today
                    )
                    .presentationEnabled()
                }
            }
            .sheet(item: $paying, onDismiss: openPendingEdit) { target in
                ExpenseSheet(target: target, today: incomeStore.today) { expense in
                    pendingEdit = expense
                }
                .presentationEnabled()
            }
    }

    private func openPendingEdit() {
        guard let expense = pendingEdit else { return }
        pendingEdit = nil
        editing = ExpenseDraft(expense: expense, snapshot: store.snapshot, today: incomeStore.today)
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }
}

extension View {
    func expenseFlow(paying: Binding<ExpenseSheetTarget?>, editing: Binding<ExpenseDraft?>) -> some View {
        modifier(ExpenseFlow(paying: paying, editing: editing))
    }
}
