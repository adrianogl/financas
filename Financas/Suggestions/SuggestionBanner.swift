import SwiftUI

struct SuggestionBanner: View {
    @Environment(SuggestionStore.self) private var store
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        let pending = store.pending
        if !pending.isEmpty {
            Button {
                navigation.isReviewingSuggestions = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.title3)
                        .foregroundStyle(Theme.review)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title(pending.count))
                            .font(.subheadline.weight(.semibold))
                        Text("\(IncomeFormat.currency(pending.map(\.amount).reduce(0, +))) ainda fora dos gastos do mês")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .glassEffect(.regular.tint(Theme.reviewTint.opacity(0.18)), in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
    }

    private func title(_ count: Int) -> String {
        count == 1 ? "1 compra da Carteira para revisar" : "\(count) compras da Carteira para revisar"
    }
}
