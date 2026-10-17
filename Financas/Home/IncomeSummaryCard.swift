import SwiftUI

struct IncomeSummaryCard: View {
    @Environment(IncomeStore.self) private var store
    let openIncomes: () -> Void

    var body: some View {
        Button(action: openIncomes) {
            content
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 96)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Tentar de novo") {
                    Task { await store.load() }
                }
                .buttonStyle(.glass)
            }
        case .loaded:
            if store.snapshot.incomes.isEmpty {
                emptyState
            } else {
                summary(store.summary(for: store.selectedMonth))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Receitas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Cadastre sua primeira receita")
                .font(.headline)
            Text("Veja quanto falta receber no mês e quando cai cada valor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Falta receber em \(IncomeFormat.monthName(store.selectedMonth))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if summary.overdueCount > 0 {
                    OverdueBadge(text: summary.overdueCount == 1 ? "1 atrasada" : "\(summary.overdueCount) atrasadas")
                }
            }
            Text(IncomeFormat.currency(summary.remaining))
                .font(.system(size: 26, weight: .semibold))
                .monospacedDigit()
            ProgressView(value: progress(summary))
                .tint(Theme.accent)
                .padding(.top, 6)
            Text("\(IncomeFormat.currency(summary.received)) de \(IncomeFormat.currency(summary.expected)) já entrou")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let next = summary.next {
                Divider()
                    .padding(.vertical, 6)
                HStack {
                    Text("Próxima: \(Text(next.income.name).fontWeight(.semibold).foregroundStyle(.primary)) · \(IncomeFormat.shortDate(next.dueDate))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .font(.footnote)
            }
        }
    }

    private func progress(_ summary: MonthSummary) -> Double {
        guard summary.expected > 0 else { return 0 }
        return NSDecimalNumber(decimal: summary.received / summary.expected).doubleValue
    }
}
