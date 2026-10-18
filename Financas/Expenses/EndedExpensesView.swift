import SwiftUI

struct EndedExpensesView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    let edit: (Expense) -> Void

    var body: some View {
        let ended = store.endedExpenses(today: incomeStore.today)

        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(ended) { expense in
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
                    if expense.id != ended.last?.id {
                        Divider()
                    }
                }
            }
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .padding(20)
            .readableWidth(LayoutConstants.contentWidth)
        }
        .background(AppBackground())
        .navigationTitle("Encerradas")
    }
}
