import Charts
import SwiftUI

struct BalanceChartCard: View {
    let summary: HomeMonthSummary
    let chartHeight: CGFloat
    let showsDayScale: Bool
    var title: String?

    var body: some View {
        let domain = summary.chartDomain
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.headline)
            } else {
                Text("Saldo de \(IncomeFormat.monthName(summary.month))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(IncomeFormat.currency(summary.balance))
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Chart(summary.points) { point in
                AreaMark(
                    x: .value("Dia", point.day),
                    yStart: .value("Base", domain.lowerBound),
                    yEnd: .value("Saldo", point.balance)
                )
                .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Dia", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartXAxis {
                AxisMarks(values: HomeDayScale.days(in: summary.month)) { value in
                    AxisValueLabel(anchor: labelAnchor(index: value.index, count: value.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(showsDayScale ? .visible : .hidden)
            .chartYAxis(.hidden)
            .chartXScale(domain: 1...summary.month.dayCount)
            .chartYScale(domain: domain)
            .frame(height: chartHeight)
            .padding(.top, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.smooth, value: summary)
    }

    private func labelAnchor(index: Int, count: Int) -> UnitPoint {
        if index == 0 { return .topLeading }
        return index == count - 1 ? .topTrailing : .top
    }
}
