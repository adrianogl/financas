import SwiftUI

struct IncomeDetailView: View {
    @Environment(IncomeStore.self) private var store
    let occurrenceID: String
    let month: YearMonth
    @State private var receiving: IncomeOccurrence?
    @State private var editing: IncomeDraft?
    @State private var isUnmarking = false

    var body: some View {
        DetailScaffold(item: occurrence) { occurrence in
            content(occurrence)
        }
        .incomeReceiptFlow(receiving: $receiving, editing: $editing)
    }

    private var occurrence: IncomeOccurrence? {
        store.occurrences(in: month).first { $0.id == occurrenceID }
    }

    private func content(_ occurrence: IncomeOccurrence) -> some View {
        let summary = IncomeDetailSummary.make(occurrence: occurrence, snapshot: store.snapshot, today: store.today)
        return VStack(alignment: .leading, spacing: 18) {
            DetailHeader(rule: summary.rule, title: IncomeFormat.occurrenceTitle(occurrence)) {
                editing = IncomeDraft(income: occurrence.income, snapshot: store.snapshot, today: store.today)
            }
            HStack(alignment: .top, spacing: 12) {
                amountBox(occurrence)
                if let current = summary.current {
                    DetailAmountBox(
                        title: "Valor atual",
                        value: currentText(current, kind: occurrence.income.kind),
                        caption: "desde \(IncomeFormat.shortMonthYear(current.validFrom))"
                    )
                }
            }
            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .padding(.horizontal, 6)
            }
            if occurrence.status == .received {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { receivedActions(occurrence) }
                    VStack(alignment: .leading, spacing: 10) { receivedActions(occurrence) }
                }
            } else {
                GlassPrimaryButton(title: "Marcar como recebida") {
                    receiving = occurrence
                }
            }
            if !summary.history.isEmpty {
                DetailHistoryList(
                    entries: summary.history,
                    sign: "+",
                    missingText: "não recebida",
                    amountColor: Theme.positive
                )
            }
        }
    }

    @ViewBuilder
    private func receivedActions(_ occurrence: IncomeOccurrence) -> some View {
        Button("Alterar recebimento") {
            receiving = occurrence
        }
        .buttonStyle(.glass)
        Button("Desmarcar recebimento", role: .destructive) {
            unmark(occurrence)
        }
        .buttonStyle(.glass)
        .tint(Theme.warning)
        .disabled(isUnmarking)
    }

    @ViewBuilder
    private func amountBox(_ occurrence: IncomeOccurrence) -> some View {
        let monthName = IncomeFormat.occurrenceMonthName(occurrence)
        if let receipt = occurrence.receipt, occurrence.status == .received {
            DetailAmountBox(
                title: "Recebido em \(monthName)",
                value: IncomeFormat.currency(receipt.amount),
                caption: receivedCaption(receipt, expected: occurrence.expectedAmount),
                valueColor: Theme.positive,
                tint: Theme.positive
            )
        } else {
            DetailAmountBox(
                title: "Previsto para \(monthName)",
                value: IncomeFormat.currency(occurrence.expectedAmount),
                caption: DueText.text(dueDate: occurrence.dueDate, today: store.today),
                tint: Theme.accent
            )
        }
    }

    private func receivedCaption(_ receipt: IncomeReceipt, expected: Decimal) -> String {
        let date = "em \(IncomeFormat.shortDate(receipt.receivedOn))"
        guard receipt.amount != expected else { return "\(date) · como previsto" }
        return "\(date) · previsto \(IncomeFormat.currency(expected))"
    }

    private func currentText(_ current: IncomeAmount, kind: IncomeKind) -> String {
        let value = IncomeFormat.currency(current.amount)
        return kind == .hourly ? "\(value)/h" : value
    }

    private func unmark(_ occurrence: IncomeOccurrence) {
        isUnmarking = true
        Task {
            _ = await store.unmarkReceived(occurrence)
            isUnmarking = false
        }
    }
}
