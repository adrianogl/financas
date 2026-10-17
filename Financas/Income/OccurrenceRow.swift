import SwiftUI

struct OccurrenceRow: View {
    let occurrence: IncomeOccurrence

    var body: some View {
        HStack(spacing: 12) {
            IncomeIcon(systemImage: iconName, tint: iconTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(IncomeFormat.occurrenceTitle(occurrence))
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(occurrence.status == .received ? Theme.positive : .primary)
                if occurrence.status == .overdue {
                    OverdueBadge(text: "atrasada")
                } else if let receipt = occurrence.receipt, receipt.amount != occurrence.expectedAmount {
                    Text("previsto \(IncomeFormat.currency(occurrence.expectedAmount))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private var caption: String {
        let date = IncomeFormat.shortDate(occurrence.receipt?.receivedOn ?? occurrence.dueDate)
        guard let days = occurrence.receipt?.workedDays ?? occurrence.businessDays,
              let hours = occurrence.income.hoursPerDay else { return date }
        return "\(date) · \(days) dias × \(hours.formatted(.number.locale(IncomeFormat.locale)))h"
    }

    private var amountText: String {
        guard let receipt = occurrence.receipt else { return IncomeFormat.currency(occurrence.expectedAmount) }
        return "+ \(IncomeFormat.currency(receipt.amount))"
    }

    private var iconName: String {
        if occurrence.status == .received { return "checkmark" }
        return occurrence.income.kind.systemImage
    }

    private var iconTint: Color {
        occurrence.status == .received ? Theme.positive : occurrence.income.kind.tint
    }
}
