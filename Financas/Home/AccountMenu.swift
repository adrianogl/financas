import SwiftUI

struct AccountMenu<Label: View>: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @Environment(AvatarStore.self) private var avatarStore
    @Environment(AccountMenuState.self) private var state
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Button("Escolher foto", systemImage: "photo") {
                state.showsPhotoPicker = true
            }
            if avatarStore.imageData != nil {
                Button("Remover foto", systemImage: "trash") {
                    removePhoto()
                }
            }
            Button("Configurações", systemImage: "gearshape") {
                state.showsSettings = true
            }
            Button("Bloquear", systemImage: "lock") {
                lockManager.lock()
            }
            Button("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                state.confirmsSignOut = true
            }
        } label: {
            label()
        }
    }

    private func removePhoto() {
        guard let user = account.user else { return }
        Task { _ = await avatarStore.remove(for: user) }
    }
}
