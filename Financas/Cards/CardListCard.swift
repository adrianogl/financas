import SwiftUI

struct CardListCard<Item: Hashable, Row: View>: View {
    let items: [Item]
    let emptyText: String
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Divider()
                }
                row(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: CardConstants.cardCornerRadius))
    }
}
