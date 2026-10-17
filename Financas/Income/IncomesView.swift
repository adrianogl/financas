import SwiftUI

struct IncomesView: View {
    @Environment(IncomeStore.self) private var store
    @State private var editing: IncomeDraft?
    @State private var receiving: IncomeOccurrence?

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonthPicker(month: $store.selectedMonth)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Receitas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nova receita", systemImage: "plus") {
                        editing = IncomeDraft(today: store.today)
                    }
                }
            }
            .refreshable { await store.load() }
            .sheet(isPresented: isEditing) {
                if let draft = editing {
                    Text(draft.name)
                }
            }
            .sheet(item: $receiving) { occurrence in
                Text(IncomeFormat.occurrenceTitle(occurrence))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tentar de novo") {
                    Task { await store.load() }
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        case .loaded:
            if store.snapshot.incomes.isEmpty {
                emptyState
            } else {
                monthContent
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
            GlassPrimaryButton(title: "Cadastrar receita") {
                editing = IncomeDraft(today: store.today)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var monthContent: some View {
        let month = store.selectedMonth
        let occurrences = store.occurrences(in: month)
        let open = occurrences
            .filter { $0.status != .received }
            .sorted { ($0.status == .overdue ? 0 : 1, $0.dueDate) < ($1.status == .overdue ? 0 : 1, $1.dueDate) }
        let received = occurrences.filter { $0.status == .received }

        IncomeMonthSummaryCard(summary: store.summary(for: month))

        if let message = store.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .padding(.horizontal, 6)
        }

        if !open.isEmpty {
            section("Pendentes", occurrences: open)
        }
        if !received.isEmpty {
            section("Recebidas", occurrences: received)
        }
        if occurrences.isEmpty {
            Text("Nenhuma receita prevista para \(IncomeFormat.monthName(month)).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        if month >= store.today.yearMonth, !store.activeRecurring.isEmpty || !store.endedRecurring.isEmpty {
            registered
        }
    }

    private func section(_ title: String, occurrences: [IncomeOccurrence]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(occurrences) { occurrence in
                    Button {
                        receiving = occurrence
                    } label: {
                        OccurrenceRow(occurrence: occurrence)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Editar receita", systemImage: "pencil") {
                            edit(occurrence.income)
                        }
                    }
                    if occurrence.id != occurrences.last?.id {
                        Divider().padding(.leading, 48)
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
                    Divider().padding(.leading, 48)
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

    private func edit(_ income: Income) {
        editing = IncomeDraft(income: income, snapshot: store.snapshot, today: store.today)
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }
}
