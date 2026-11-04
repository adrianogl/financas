import Charts
import SwiftUI

struct MonthComparisonCard: View {
    let months: [MonthComparison]
    @Binding var selected: YearMonth
    @State private var tapped: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Receitas e despesas")
                    .font(.headline)
                Text("Últimos \(HomeConstants.comparisonPastMonths) meses e previsão dos próximos \(HomeConstants.comparisonForecastMonths)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            legend
            chart
            if let item = months.first(where: { $0.month == selected }) {
                Divider()
                totals(item)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.smooth, value: months)
        .animation(.smooth, value: selected)
    }

    private var chart: some View {
        Chart {
            if months.contains(where: { $0.month == selected }) {
                RectangleMark(x: .value("Mês", label(selected)))
                    .foregroundStyle(Theme.accent.opacity(HomeConstants.selectedMonthOpacity))
                    .clipShape(.rect(cornerRadius: 8))
            }
            ForEach(months) { item in
                bar(item, series: MonthComparisonSeries.income, value: item.income)
                bar(item, series: MonthComparisonSeries.expense, value: item.expense)
            }
        }
        .chartForegroundStyleScale([
            MonthComparisonSeries.income.title: Theme.accent,
            MonthComparisonSeries.expense.title: MonthComparisonSeries.expense.color,
        ])
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: months.map { label($0.month) })
        .chartXAxis {
            AxisMarks(values: months.map { label($0.month) }) {
                AxisValueLabel()
                    .font(.caption)
            }
        }
        .chartXSelection(value: $tapped)
        .onChange(of: tapped) { _, text in
            guard let text, let month = months.first(where: { label($0.month) == text })?.month else { return }
            selected = month
        }
        .frame(height: HomeConstants.comparisonChartHeight)
    }

    private func bar(_ item: MonthComparison, series: MonthComparisonSeries, value: Decimal) -> some ChartContent {
        BarMark(
            x: .value("Mês", label(item.month)),
            y: .value("Valor", NSDecimalNumber(decimal: value).doubleValue)
        )
        .foregroundStyle(by: .value("Tipo", series.title))
        .position(by: .value("Tipo", series.title))
        .opacity(item.isForecast ? HomeConstants.forecastOpacity : 1)
        .clipShape(.rect(cornerRadius: 3))
        .accessibilityLabel("\(series.title) de \(IncomeFormat.monthName(item.month))")
        .accessibilityValue(IncomeFormat.currency(value) + (item.isForecast ? ", previsão" : ""))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            swatch(Theme.accent, title: MonthComparisonSeries.income.title)
            swatch(MonthComparisonSeries.expense.color, title: MonthComparisonSeries.expense.title)
            swatch(Color.secondary.opacity(HomeConstants.forecastOpacity), title: "Previsão")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func swatch(_ color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
        }
    }

    private func totals(_ item: MonthComparison) -> some View {
        let month = IncomeFormat.shortMonth(item.month)
        return HStack(alignment: .top) {
            total("Receitas \(month)", value: IncomeFormat.currency(item.income), tint: nil)
            total("Despesas \(month)", value: IncomeFormat.currency(item.expense), tint: nil)
            total(
                item.isForecast ? "Sobra prevista" : "Sobrou",
                value: IncomeFormat.currency(item.balance),
                tint: item.balance < 0 ? Theme.warning : Theme.positive
            )
        }
    }

    private func total(_ title: String, value: String, tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint ?? Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ month: YearMonth) -> String {
        IncomeFormat.shortMonth(month)
    }
}
