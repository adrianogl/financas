import SwiftUI

struct ExpenseDetailView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    let occurrenceID: String
    let month: YearMonth
    @State private var paying: ExpenseSheetTarget?
    @State private var editing: ExpenseDraft?
    @State private var isUnmarking = false

    var body: some View {
        DetailScaffold(item: occurrence) { occurrence in
            content(occurrence)
        }
        .expenseFlow(paying: $paying, editing: $editing)
    }

    private var today: CalendarDay {
        incomeStore.today
    }

    private var occurrence: ExpenseOccurrence? {
        store.occurrences(in: month, today: today).first { $0.id == occurrenceID }
    }

    private func content(_ occurrence: ExpenseOccurrence) -> some View {
        let summary = ExpenseDetailSummary.make(occurrence: occurrence, snapshot: store.snapshot)
        let isPaid = occurrence.status == .paid
        let monthName = IncomeFormat.monthName(occurrence.month)
        return VStack(alignment: .leading, spacing: 18) {
            DetailHeader(rule: summary.rule, title: ExpenseFormat.occurrenceTitle(occurrence, today: today)) {
                editing = ExpenseDraft(expense: occurrence.expense, snapshot: store.snapshot, today: today)
            }
            HStack(alignment: .top, spacing: 12) {
                DetailAmountBox(
                    title: isPaid ? "Pago em \(monthName)" : "Previsto para \(monthName)",
                    value: IncomeFormat.currency(occurrence.amount),
                    caption: ExpenseFormat.origin(occurrence),
                    valueColor: isPaid ? Theme.positive : .primary,
                    tint: isPaid ? Theme.positive : Theme.accent
                )
                if !isPaid {
                    DetailAmountBox(
                        title: "Vencimento",
                        value: DueText.shortDate(occurrence.dueDate),
                        caption: DueText.relative(dueDate: occurrence.dueDate, today: today)
                    )
                }
            }
            if !occurrence.parts.isEmpty {
                ExpensePartsCard(occurrence: occurrence, snapshot: store.snapshot) { value in
                    paying = ExpenseSheetTarget(occurrence: occurrence, mode: nil, partID: value.part.id)
                }
            }
            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, 6)
            }
            if isPaid {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { paidActions(occurrence) }
                    VStack(alignment: .leading, spacing: 10) { paidActions(occurrence) }
                }
            } else {
                GlassPrimaryButton(title: "Marcar como paga") {
                    paying = ExpenseSheetTarget(occurrence: occurrence, mode: .payment)
                }
                Button(occurrence.hasBill ? "Alterar conta lançada" : "Lançar valor da conta") {
                    paying = ExpenseSheetTarget(occurrence: occurrence, mode: .bill)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
            }
            if let partsHistory = summary.partsHistory {
                ExpensePartsHistoryTable(history: partsHistory)
            } else if !summary.history.isEmpty {
                DetailHistoryList(entries: summary.history, sign: "−", missingText: "não paga")
            }
        }
    }

    @ViewBuilder
    private func paidActions(_ occurrence: ExpenseOccurrence) -> some View {
        Button("Alterar pagamento") {
            paying = ExpenseSheetTarget(occurrence: occurrence, mode: .payment)
        }
        .buttonStyle(.glass)
        Button("Desmarcar pagamento", role: .destructive) {
            unmark(occurrence)
        }
        .buttonStyle(.glass)
        .tint(Theme.warning)
        .disabled(isUnmarking)
    }

    private func unmark(_ occurrence: ExpenseOccurrence) {
        isUnmarking = true
        Task {
            _ = await store.unmarkPaid(ExpenseBillDraft(occurrence: occurrence, today: today), for: occurrence)
            isUnmarking = false
        }
    }
}
