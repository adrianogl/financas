import SwiftUI

struct MonthBalanceCard: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(ExpenseStore.self) private var expenseStore
    let openIncomes: () -> Void
    let openExpenses: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            incomeHalf
            Divider()
                .padding(.vertical, 4)
            expenseHalf
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    @ViewBuilder
    private var incomeHalf: some View {
        switch incomeStore.loadState {
        case .idle, .loading:
            loading
        case .failed(let message):
            failure(message) { await incomeStore.load() }
        case .loaded:
            if incomeStore.snapshot.incomes.isEmpty {
                invitation("Falta receber", "Cadastre suas receitas", action: openIncomes)
            } else {
                let summary = incomeStore.summary(for: incomeStore.selectedMonth)
                half(
                    title: "Falta receber",
                    remaining: summary.remaining,
                    done: summary.received,
                    expected: summary.expected,
                    overdueCount: summary.overdueCount,
                    next: summary.next.map { "\($0.income.name) · \(IncomeFormat.shortDate($0.dueDate))" },
                    action: openIncomes
                )
            }
        }
    }

    @ViewBuilder
    private var expenseHalf: some View {
        switch expenseStore.loadState {
        case .idle, .loading:
            loading
        case .failed(let message):
            failure(message) { await expenseStore.load() }
        case .loaded:
            if expenseStore.snapshot.expenses.isEmpty {
                invitation("Falta pagar", "Cadastre suas contas fixas", action: openExpenses)
            } else {
                let summary = expenseStore.summary(for: incomeStore.selectedMonth, today: incomeStore.today)
                half(
                    title: "Falta pagar",
                    remaining: summary.remaining,
                    done: summary.paid,
                    expected: summary.expected,
                    overdueCount: summary.overdueCount,
                    next: summary.next.map { "\($0.expense.name) · \(IncomeFormat.shortDate($0.dueDate))" },
                    action: openExpenses
                )
            }
        }
    }

    private var loading: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 96)
    }

    private func failure(_ message: String, retry: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Tentar de novo") {
                Task { await retry() }
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func invitation(_ title: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.headline)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func half(
        title: String,
        remaining: Decimal,
        done: Decimal,
        expected: Decimal,
        overdueCount: Int,
        next: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if overdueCount > 0 {
                        OverdueBadge(text: "\(overdueCount)")
                            .accessibilityLabel(overdueCount == 1 ? "1 atrasada" : "\(overdueCount) atrasadas")
                    }
                }
                Text(IncomeFormat.currency(remaining))
                    .font(.system(size: 22, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                ProgressView(value: progress(done: done, expected: expected))
                    .tint(Theme.accent)
                    .padding(.top, 4)
                if let next {
                    Text(next)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func progress(done: Decimal, expected: Decimal) -> Double {
        guard expected > 0 else { return 0 }
        return NSDecimalNumber(decimal: done / expected).doubleValue
    }
}
