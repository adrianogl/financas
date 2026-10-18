import SwiftUI

struct IncomeReceiptFlow: ViewModifier {
    @Environment(IncomeStore.self) private var store
    @Binding var receiving: IncomeOccurrence?
    @Binding var editing: IncomeDraft?
    @State private var pendingEdit: Income?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isEditing) {
                if let draft = editing {
                    IncomeFormView(
                        draft: draft,
                        income: store.snapshot.incomes.first { $0.id == draft.incomeID },
                        today: store.today
                    )
                    .presentationEnabled()
                }
            }
            .sheet(item: $receiving, onDismiss: openPendingEdit) { occurrence in
                ReceiptSheet(occurrence: occurrence, today: store.today) { income in
                    pendingEdit = income
                }
                .presentationEnabled()
            }
    }

    private func openPendingEdit() {
        guard let income = pendingEdit else { return }
        pendingEdit = nil
        editing = IncomeDraft(income: income, snapshot: store.snapshot, today: store.today)
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }
}

extension View {
    func incomeReceiptFlow(receiving: Binding<IncomeOccurrence?>, editing: Binding<IncomeDraft?>) -> some View {
        modifier(IncomeReceiptFlow(receiving: receiving, editing: editing))
    }
}
