import SwiftUI

struct CardFilterBar: View {
    @Binding var filter: CardFilter
    let accounts: [CardAccount]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip("Todos", value: .all)
                ForEach(accounts) { account in
                    chip(account.nickname, value: .account(account.id))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, value: CardFilter) -> some View {
        let isSelected = filter == value
        return Button {
            filter = value
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.accent : Color.secondary.opacity(CardConstants.chipOpacity), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
