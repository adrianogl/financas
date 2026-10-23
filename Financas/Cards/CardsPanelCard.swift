import SwiftUI

struct CardsPanelCard: View {
    let months: [CommitmentMonth]
    let chartHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = months.first {
                Text("Comprometido em \(IncomeFormat.monthName(next.month))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(IncomeFormat.currency(next.total))
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack {
                    split("parcelas", next.installments, color: Theme.accent)
                    Spacer(minLength: 8)
                    split("fixos", next.fixed, color: Theme.fixedCharge)
                }
            }
            CommitmentChart(months: months, height: chartHeight)
                .padding(.top, 8)
            HStack(spacing: 14) {
                legend("Parcelas", color: Theme.accent)
                legend("Fixos", color: Theme.fixedCharge)
                Spacer(minLength: 8)
                Text("próximos 12 meses")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: CardConstants.cardCornerRadius))
    }

    private func split(_ title: String, _ value: Decimal, color: Color) -> some View {
        HStack(spacing: 6) {
            CardPill(text: title, color: color)
            Text(IncomeFormat.currency(value))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
        }
    }
}
