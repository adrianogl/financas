import SwiftUI

struct NewPasswordView: View {
    @Environment(AccountManager.self) private var account

    @State private var password = ""
    @State private var confirmation = ""
    @State private var mismatch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppMark(size: 56)
                    .padding(.top, 24)
                Text("Crie uma nova senha")
                    .font(.largeTitle.bold())
                Text("Os outros aparelhos vão sair da conta e pedir a senha nova.")
                    .foregroundStyle(.secondary)

                GlassTextField(
                    title: "Nova senha (mínimo de \(AccountConstants.minimumPasswordLength) caracteres)",
                    text: $password,
                    contentType: .newPassword,
                    isSecure: true
                )
                GlassTextField(title: "Repita a nova senha", text: $confirmation, contentType: .newPassword, isSecure: true)

                AccountErrorText(message: mismatch ? "As senhas não conferem." : account.errorMessage)

                GlassPrimaryButton(title: "Salvar nova senha", isWorking: account.isWorking) {
                    Task { await save() }
                }
                .disabled(password.isEmpty || confirmation.isEmpty)

                Button("Cancelar") {
                    Task { await account.cancelPasswordRecovery() }
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .disabled(account.isWorking)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
    }

    private func save() async {
        mismatch = password != confirmation
        guard !mismatch else { return }
        await account.saveNewPassword(password)
    }
}
