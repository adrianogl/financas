import SwiftUI

struct HomeIncomeListCard: View {
    @Environment(IncomeStore.self) private var store
    let create: () -> Void
    let receive: (IncomeOccurrence) -> Void
    let open: (DetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HomeListCardHeader(title: "Receitas", addLabel: "Nova receita", add: create)
            IncomeLoadContent {
                rows
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var rows: some View {
        let items = IncomeMonthList(occurrences: store.occurrences(in: store.selectedMonth)).all
        if store.snapshot.incomes.isEmpty {
            emptyText("Nenhuma receita cadastrada.")
        } else if items.isEmpty {
            emptyText("Nenhuma receita prevista para \(IncomeFormat.monthName(store.selectedMonth)).")
        } else {
            ForEach(items) { occurrence in
                row(occurrence)
                if occurrence.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    private func row(_ occurrence: IncomeOccurrence) -> some View {
        HStack(spacing: 12) {
            Button {
                open(.income(id: occurrence.id, month: occurrence.month))
            } label: {
                OccurrenceRow(occurrence: occurrence, isSelected: false)
            }
            .buttonStyle(.plain)
            if occurrence.status != .received {
                HomePillButton(title: "Receber", tint: Theme.positive) {
                    receive(occurrence)
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
