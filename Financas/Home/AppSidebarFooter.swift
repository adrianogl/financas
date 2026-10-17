import SwiftUI

struct AppSidebarFooter: View {
    @Environment(AccountManager.self) private var account

    var body: some View {
        AccountMenu {
            HStack(spacing: 10) {
                AccountAvatar(size: NavigationConstants.footerAvatarSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.userName ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Conta e configurações")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
