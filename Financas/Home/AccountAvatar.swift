import SwiftUI

struct AccountAvatar: View {
    @Environment(AccountManager.self) private var account
    @Environment(AvatarStore.self) private var avatarStore
    var size: CGFloat = 36

    var body: some View {
        AvatarView(
            initial: account.user.map(AvatarStore.initial) ?? "?",
            imageData: avatarStore.imageData,
            isUploading: avatarStore.isUploading,
            size: size
        )
    }
}
