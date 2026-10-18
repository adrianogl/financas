import SwiftUI

struct ExpensePartsHistoryTable: View {
    let history: ExpensePartsHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos meses")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                        .gridColumnAlignment(.leading)
                    ForEach(history.columns) { part in
                        header(part.name)
                    }
                    header("Total")
                }
                ForEach(history.rows) { row in
                    Divider()
                    GridRow {
                        Text(IncomeFormat.shortMonth(row.month))
                            .font(.subheadline)
                        ForEach(history.columns) { part in
                            cell(row.amounts[part.id], color: row.increased.contains(part.id) ? Theme.warning : .primary)
                        }
                        cell(row.total, color: .primary)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func cell(_ value: Decimal?, color: Color) -> some View {
        if let value {
            Text(ExpenseFormat.tableAmount(value))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
