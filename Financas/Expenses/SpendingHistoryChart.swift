import Charts
import SwiftUI

struct SpendingHistoryChart: View {
    let history: [SpendingMonth]
    let selected: YearMonth

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos meses")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            Chart(history) { item in
                BarMark(
                    x: .value("Mês", IncomeFormat.shortMonth(item.month)),
                    y: .value("Gasto", NSDecimalNumber(decimal: item.spent).doubleValue)
                )
                .cornerRadius(6)
                .foregroundStyle(item.month == selected ? Theme.accent : Theme.accent.opacity(ExpenseConstants.spendingOtherMonthOpacity))
                .accessibilityValue(IncomeFormat.currency(item.spent))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: ExpenseConstants.spendingChartHeight)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }
}
