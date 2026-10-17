import SwiftUI

struct IncomeMonthSummaryCard: View {
    let summary: MonthSummary

    var body: some View {
        HStack(alignment: .top) {
            column("Recebido", summary.received, color: Theme.positive, alignment: .leading)
            Spacer()
            column("Falta", summary.remaining, color: .primary, alignment: .center)
            Spacer()
            column("Previsto", summary.expected, color: .primary, alignment: .trailing)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func column(_ title: String, _ value: Decimal, color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value.formatted(.number.precision(.fractionLength(2)).locale(IncomeFormat.locale)))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}
