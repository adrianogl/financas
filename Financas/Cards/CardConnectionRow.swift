import SwiftUI

struct CardConnectionRow: View {
    let connection: CardConnection
    let accounts: [CardAccount]
    let onRename: (CardAccount) -> Void
    let onReconnect: () -> Void

    var body: some View {
        let now = Date.now
        let status = CardFormat.statusText(connection, now: now)

        VStack(alignment: .leading, spacing: 10) {
            if accounts.isEmpty {
                line(title: "Conexão", detail: "Aguardando a primeira atualização", status: status)
            }
            ForEach(accounts) { account in
                Button {
                    onRename(account)
                } label: {
                    line(title: account.nickname, detail: CardFormat.accountDetailText(institution: connection.institutionName, brandLabel: account.brandLabel, lastDigits: account.lastDigits), status: status)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            if connection.status != .active {
                Button("Reconectar", action: onReconnect)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func line(title: String, detail: String, status: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(status)
                .font(.footnote.weight(.medium))
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch connection.status {
        case .needsReconnect, .error: Theme.warning
        case .active:
            connection.lastSyncedAt.map { Calendar.current.isDateInToday($0) } == true ? Theme.positive : .secondary
        }
    }
}
