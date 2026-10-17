import SwiftUI

struct HomeExpenseListCard: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    let create: () -> Void
    let pay: (ExpenseOccurrence) -> Void
    let open: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeListCardHeader(title: "Despesas", addLabel: "Nova despesa", add: create)
            ExpenseLoadContent {
                rows
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var rows: some View {
        let month = incomeStore.selectedMonth
        let items = ExpenseMonthList(occurrences: store.occurrences(in: month, today: incomeStore.today)).all
        if store.snapshot.expenses.isEmpty {
            emptyText("Nenhuma despesa cadastrada.")
        } else if items.isEmpty {
            emptyText("Nenhuma despesa prevista para \(IncomeFormat.monthName(month)).")
        } else {
            ForEach(items) { occurrence in
                row(occurrence)
                if occurrence.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    private func row(_ occurrence: ExpenseOccurrence) -> some View {
        HStack(spacing: 12) {
            Button {
                open(.expense(id: occurrence.id, month: occurrence.month))
            } label: {
                ExpenseOccurrenceRow(occurrence: occurrence, today: incomeStore.today, isSelected: false)
            }
            .buttonStyle(.plain)
            if occurrence.status != .paid {
                HomePillButton(title: "Pagar", tint: Theme.accent) {
                    pay(occurrence)
                }
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }
}
