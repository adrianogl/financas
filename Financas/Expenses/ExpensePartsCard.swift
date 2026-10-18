import SwiftUI

struct ExpensePartsCard: View {
    let occurrence: ExpenseOccurrence
    let snapshot: ExpenseSnapshot
    let select: (ExpensePartValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(occurrence.parts) { value in
                Button {
                    select(value)
                } label: {
                    row(value)
                }
                .buttonStyle(.plain)
                if value.id != occurrence.parts.last?.id {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func row(_ value: ExpensePartValue) -> some View {
        let change = ExpensePartSchedule.change(of: value.part, in: occurrence.month, snapshot: snapshot)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value.part.name)
                    .font(.subheadline.weight(.medium))
                Text(ExpenseFormat.partCaption(value, change: change, previous: occurrence.month.previous))
                    .font(.caption.weight(isHighlighted(value, change: change) ? .semibold : .regular))
                    .foregroundStyle(changeColor(value, change: change))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(IncomeFormat.currency(value.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(ExpenseFormat.partStatus(value))
                    .font(.caption)
                    .foregroundStyle(statusColor(value))
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }

    private func isHighlighted(_ value: ExpensePartValue, change: Decimal?) -> Bool {
        guard !value.isFixed, let change else { return false }
        return change != 0
    }

    private func changeColor(_ value: ExpensePartValue, change: Decimal?) -> Color {
        guard isHighlighted(value, change: change), let change else { return .secondary }
        return change > 0 ? Theme.warning : Theme.positive
    }

    private func statusColor(_ value: ExpensePartValue) -> Color {
        switch value.status {
        case .paid: Theme.positive
        case .overdue: Theme.warning
        case .pending: .secondary
        }
    }
}
