import SwiftUI

struct SuggestionReviewCard: View {
    @Environment(SuggestionStore.self) private var store
    @Environment(CardStore.self) private var cards
    @State private var selectedID: UUID?
    @State private var autoLaunch = false
    @State private var conflict: SuggestionConflict?
    let suggestion: SpendingSuggestion
    let today: CalendarDay

    var body: some View {
        let options = store.options(for: suggestion, today: today)
        let overlap = CardOverlap.installment(for: suggestion, in: cards.snapshot.transactions)

        VStack(alignment: .leading, spacing: 12) {
            header
            if let overlap, let total = overlap.totalInstallments {
                overlapWarning(total: total, installment: overlap.amount)
            }
            if options.isEmpty {
                Text(SpendingIntentConstants.noSpendingsMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                choices(options)
                Toggle("Lançar direto da próxima vez", isOn: $autoLaunch)
                    .font(.subheadline)
            }
            actions(options, hasOverlap: overlap != nil)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .onAppear {
            if selectedID == nil {
                selectedID = store.suggestedExpense(for: suggestion, options: options)?.id
            }
            autoLaunch = store.autoLaunches(suggestion)
        }
        .confirmationDialog(
            "Já lançado em \(conflict?.launchedName ?? "")",
            isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } }),
            titleVisibility: .visible,
            presenting: conflict
        ) { conflict in
            Button("Mover para \(conflict.chosen.name)") {
                Task { _ = await store.move(suggestion, to: conflict.chosen) }
            }
            Button("Manter em \(conflict.launchedName)", role: .cancel) {}
        } message: { _ in
            Text("Essa compra foi confirmada em outro aparelho.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.merchant)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text("\(SuggestionCatalog.detail(of: suggestion)) · \(suggestion.firstDeviceName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(IncomeFormat.currency(suggestion.amount))
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
    }

    private func overlapWarning(total: Int, installment: Decimal) -> some View {
        Label {
            Text("O cartão trouxe esta compra em \(total)× de \(IncomeFormat.currency(installment)). As parcelas já entram no comprometido do cartão, então lançar como gasto do mês contaria duas vezes.")
                .font(.footnote)
        } icon: {
            Image(systemName: "creditcard")
        }
        .foregroundStyle(Theme.review)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.reviewTint.opacity(0.14), in: .rect(cornerRadius: 12))
    }

    private func choices(_ options: [Expense]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { expense in
                    let isSelected = expense.id == selectedID
                    Button(expense.name) { selectedID = expense.id }
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .buttonStyle(.bordered)
                        .tint(isSelected ? Theme.accent : .secondary)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func actions(_ options: [Expense], hasOverlap: Bool) -> some View {
        HStack(spacing: 8) {
            if suggestion.status == .pending {
                Button(hasOverlap ? "Deixar no cartão" : "Não é gasto") {
                    Task { _ = await store.dismiss(suggestion) }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            Button(hasOverlap ? "Lançar mesmo assim" : "Lançar") {
                guard let expense = options.first(where: { $0.id == selectedID }) else { return }
                Task { await confirm(in: expense) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.positive)
            .frame(maxWidth: .infinity)
            .disabled(selectedID == nil || store.isSaving)
        }
        .controlSize(.large)
    }

    private func confirm(in expense: Expense) async {
        guard let result = await store.confirm(suggestion, in: expense, autoLaunch: autoLaunch),
              result.already,
              let launchedID = result.suggestion.expenseID,
              launchedID != expense.id else { return }
        let launchedName = store.options(for: suggestion, today: today).first { $0.id == launchedID }?.name ?? "outro gasto"
        conflict = SuggestionConflict(launchedName: launchedName, chosen: expense)
    }
}
