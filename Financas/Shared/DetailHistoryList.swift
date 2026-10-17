import SwiftUI

struct DetailHistoryList: View {
    let entries: [DetailHistoryEntry]
    let sign: String
    let missingText: String
    var amountColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos meses")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entries) { entry in
                    HStack {
                        Text(IncomeFormat.shortMonthYear(entry.month))
                            .font(.subheadline)
                        Spacer()
                        amount(entry.amount)
                    }
                    .padding(.vertical, 8)
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    @ViewBuilder
    private func amount(_ value: Decimal?) -> some View {
        if let value {
            Text("\(sign) \(IncomeFormat.currency(value))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        } else {
            Text(missingText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
