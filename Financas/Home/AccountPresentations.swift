import PhotosUI
import SwiftUI

struct AccountPresentations: ViewModifier {
    @Environment(AccountManager.self) private var account
    @Environment(AvatarStore.self) private var avatarStore
    @Bindable var state: AccountMenuState
    @State private var photoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .environment(state)
            .sheet(isPresented: $state.showsSettings) {
                SettingsView()
            }
            .photosPicker(isPresented: $state.showsPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                uploadPhoto(item)
            }
            .confirmationDialog("Sair da conta?", isPresented: $state.confirmsSignOut, titleVisibility: .visible) {
                Button("Sair", role: .destructive) {
                    Task { await account.signOut() }
                }
            } message: {
                Text("O PIN deste aparelho será apagado. Para voltar, entre com seu e-mail e senha.")
            }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) {
        guard let user = account.user else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            _ = await avatarStore.upload(data, for: user)
        }
    }
}

extension View {
    func accountPresentations(_ state: AccountMenuState) -> some View {
        modifier(AccountPresentations(state: state))
    }
}
