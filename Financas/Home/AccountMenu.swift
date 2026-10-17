import PhotosUI
import SwiftUI

struct AccountMenu<Label: View>: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @Environment(AvatarStore.self) private var avatarStore
    @ViewBuilder let label: () -> Label
    @State private var confirmsSignOut = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showsPhotoPicker = false
    @State private var showsSettings = false

    var body: some View {
        Menu {
            Button("Escolher foto", systemImage: "photo") {
                showsPhotoPicker = true
            }
            if avatarStore.imageData != nil {
                Button("Remover foto", systemImage: "trash") {
                    removePhoto()
                }
            }
            Button("Configurações", systemImage: "gearshape") {
                showsSettings = true
            }
            Button("Bloquear", systemImage: "lock") {
                lockManager.lock()
            }
            Button("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                confirmsSignOut = true
            }
        } label: {
            label()
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            uploadPhoto(item)
        }
        .confirmationDialog("Sair da conta?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
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

    private func removePhoto() {
        guard let user = account.user else { return }
        Task { _ = await avatarStore.remove(for: user) }
    }
}
