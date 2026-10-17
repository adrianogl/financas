import SwiftUI

struct IncomesView: View {
    @Environment(IncomeStore.self) private var store
    @State private var editing: IncomeDraft?

    var body: some View {
        @Bindable var store = store
        let open = openOccurrences
        let received = receivedOccurrences

        NavigationStack {
            ListDetailLayout(
                section: .incomes,
                title: "Receitas",
                add: SectionAddAction(title: "Nova receita", action: create),
                routes: (open + received).map(route),
                openRoutes: open.map(route),
                isLoaded: store.loadState == .loaded,
                emptyText: hasMonthList ? emptyMonthText : nil
            ) { context in
                MonthPicker(month: $store.selectedMonth)
                content(context, open: open, received: received)
            }
            .refreshable { await store.load() }
            .incomeReceiptFlow(receiving: .constant(nil), editing: $editing)
            .detailDestination()
        }
    }

    private var hasMonthList: Bool {
        store.loadState == .loaded && !store.snapshot.incomes.isEmpty
    }

    private var monthOccurrences: [IncomeOccurrence] {
        hasMonthList ? store.occurrences(in: store.selectedMonth) : []
    }

    private var openOccurrences: [IncomeOccurrence] {
        monthOccurrences
            .filter { $0.status != .received }
            .sorted { ($0.status == .overdue ? 0 : 1, $0.dueDate) < ($1.status == .overdue ? 0 : 1, $1.dueDate) }
    }

    private var receivedOccurrences: [IncomeOccurrence] {
        monthOccurrences.filter { $0.status == .received }
    }

    private var emptyMonthText: String {
        "Nenhuma receita prevista para \(IncomeFormat.monthName(store.selectedMonth))."
    }

    private func route(_ occurrence: IncomeOccurrence) -> DetailRoute {
        .income(id: occurrence.id, month: occurrence.month)
    }

    private func content(_ context: ListDetailContext, open: [IncomeOccurrence], received: [IncomeOccurrence]) -> some View {
        IncomeLoadContent {
            if store.snapshot.incomes.isEmpty {
                emptyState
            } else {
                monthContent(context, open: open, received: received)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nenhuma receita cadastrada")
                .font(.headline)
            Text("Cadastre suas receitas fixas, por hora ou avulsas para ver quanto falta receber no mês.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            GlassPrimaryButton(title: "Cadastrar receita", action: create)
                .padding(.top, 6)
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private func monthContent(_ context: ListDetailContext, open: [IncomeOccurrence], received: [IncomeOccurrence]) -> some View {
        let month = store.selectedMonth

        IncomeMonthSummaryCard(summary: store.summary(for: month))

        if let message = store.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .padding(.horizontal, 6)
        }

        if !open.isEmpty {
            section("Pendentes", occurrences: open, context: context)
        }
        if !received.isEmpty {
            section("Recebidas", occurrences: received, context: context)
        }
        if open.isEmpty && received.isEmpty {
            Text(emptyMonthText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        if month >= store.today.yearMonth, !store.activeRecurring.isEmpty || !store.endedRecurring.isEmpty {
            registered
        }
    }

    private func section(_ title: String, occurrences: [IncomeOccurrence], context: ListDetailContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            DetailRowList(items: occurrences, context: context, route: route) { occurrence, isSelected in
                OccurrenceRow(occurrence: occurrence, isSelected: isSelected)
                    .contextMenu {
                        Button("Editar receita", systemImage: "pencil") {
                            edit(occurrence.income)
                        }
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    private var registered: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Cadastradas")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.activeRecurring) { income in
                    Button {
                        edit(income)
                    } label: {
                        RecurringIncomeRow(income: income, rate: store.currentAmount(for: income))
                    }
                    .buttonStyle(.plain)
                    if income.id != store.activeRecurring.last?.id || !store.endedRecurring.isEmpty {
                        Divider()
                    }
                }
                if !store.endedRecurring.isEmpty {
                    NavigationLink {
                        EndedIncomesView(edit: edit)
                    } label: {
                        HStack {
                            Text("Encerradas")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(store.endedRecurring.count)")
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
        editing = IncomeDraft(today: store.today, kind: store.settings.orderedEnabledKinds.first ?? .fixed)
    }

    private func edit(_ income: Income) {
        editing = IncomeDraft(income: income, snapshot: store.snapshot, today: store.today)
    }
}
