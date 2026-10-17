import SwiftUI

struct HomeHeader: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @Environment(AvatarStore.self) private var avatarStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CollapsingAppLogo(markSize: 44, isVisible: lockManager.isUnlocked)
                .padding(.bottom, 10)
            Text(Greeting.text(hour: Calendar.current.component(.hour, from: .now), name: account.userName ?? ""))
                .font(.largeTitle.bold())
            Text(Greeting.dateText(for: .now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let message = avatarStore.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                    .padding(.top, 4)
            }
        }
    }
}
