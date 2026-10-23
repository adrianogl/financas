import SwiftUI

struct CardInstallmentRow: View {
    let plan: InstallmentPlan
    let nickname: String
    let today: CalendarDay

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(nickname) · \(CardFormat.progressText(plan, today: today))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(IncomeFormat.currency(plan.installmentAmount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }
}
