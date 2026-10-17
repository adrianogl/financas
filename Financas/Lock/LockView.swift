import SwiftUI

struct LockView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(AccountManager.self) private var account
    @State private var confirmsSignOut = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            AppLogo(markSize: 88)
                .padding(.bottom, 4)
            Text("Bloqueado")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage = lockManager.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            Spacer()

            Button {
                Task { await lockManager.unlock() }
            } label: {
                Label("Desbloquear", systemImage: lockManager.biometry.systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            Button("Sair da conta", role: .destructive) {
                confirmsSignOut = true
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
        .padding(32)
        .readableWidth()
        .background(AppBackground())
        .onAppear { lockManager.autoUnlockIfNeeded() }
        .confirmationDialog("Sair da conta?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sair", role: .destructive) {
                Task { await account.signOut() }
            }
        } message: {
            Text("O PIN deste aparelho será apagado. Para voltar, entre com seu e-mail e senha.")
        }
    }
}
