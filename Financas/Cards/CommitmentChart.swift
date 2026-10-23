import Charts
import SwiftUI

struct CommitmentChart: View {
    let months: [CommitmentMonth]
    let height: CGFloat

    var body: some View {
        let first = months.first.map { IncomeFormat.shortMonth($0.month) }

        Chart {
            ForEach(months) { item in
                let label = IncomeFormat.shortMonth(item.month)
                BarMark(
                    x: .value("Mês", label),
                    y: .value("Valor", NSDecimalNumber(decimal: item.fixed).doubleValue)
                )
                .foregroundStyle(by: .value("Tipo", "Fixos"))
                BarMark(
                    x: .value("Mês", label),
                    y: .value("Valor", NSDecimalNumber(decimal: item.installments).doubleValue)
                )
                .foregroundStyle(by: .value("Tipo", "Parcelas"))
            }
        }
        .chartForegroundStyleScale(["Parcelas": Theme.accent, "Fixos": Theme.fixedCharge])
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.caption2.weight(label == first ? .bold : .regular))
                            .foregroundStyle(label == first ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Comprometido nos próximos 12 meses")
        .accessibilityValue(months.map { "\(IncomeFormat.monthName($0.month)): \(IncomeFormat.currency($0.total))" }.joined(separator: ", "))
    }
}
