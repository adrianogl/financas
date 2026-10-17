import SwiftUI

struct EndedIncomesView: View {
    @Environment(IncomeStore.self) private var store
    let edit: (Income) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.endedRecurring) { income in
                    Button {
                        edit(income)
                    } label: {
                        RecurringIncomeRow(income: income, rate: store.currentAmount(for: income))
                    }
                    .buttonStyle(.plain)
                    if income.id != store.endedRecurring.last?.id {
                        Divider().padding(.leading, 48)
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
