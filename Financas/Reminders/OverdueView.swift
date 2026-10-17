import SwiftUI

struct OverdueView: View {
    @Environment(IncomeStore.self) private var store
    @State private var editing: IncomeDraft?
    @State private var receiving: IncomeOccurrence?
    @State private var pendingEdit: Income?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Atrasadas")
            .refreshable { await store.load() }
            .sheet(isPresented: isEditing) {
                if let draft = editing {
                    IncomeFormView(
                        draft: draft,
                        income: store.snapshot.incomes.first { $0.id == draft.incomeID },
                        today: store.today
                    )
                }
            }
            .sheet(item: $receiving, onDismiss: openPendingEdit) { occurrence in
                ReceiptSheet(occurrence: occurrence, today: store.today) { income in
                    pendingEdit = income
                }
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
            if store.overdueOccurrences.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nada atrasado")
                .font(.headline)
            Text("Quando uma receita passar da data sem ser marcada como recebida, ela aparece aqui.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var list: some View {
        let occurrences = store.overdueOccurrences

        OverdueTotalCard(total: store.overdueTotal)

        VStack(alignment: .leading, spacing: 8) {
            Text("Receitas")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(occurrences) { occurrence in
                    Button {
                        receiving = occurrence
                    } label: {
                        OverdueRow(occurrence: occurrence, today: store.today)
                    }
                    .buttonStyle(.plain)
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

    private func openPendingEdit() {
        guard let income = pendingEdit else { return }
        pendingEdit = nil
        editing = IncomeDraft(income: income, snapshot: store.snapshot, today: store.today)
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }
}
