import SwiftUI

struct ConfirmEmailView: View {
    @Environment(AccountManager.self) private var account
    let email: String

    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 24)
                Text("Confirme seu e-mail")
                    .font(.largeTitle.bold())
                Text("Enviamos um link para **\(email)**. Toque nele e depois volte aqui para entrar.")
                    .foregroundStyle(.secondary)

                GlassTextField(title: "Senha", text: $password, contentType: .password, isSecure: true)

                AccountErrorText(message: account.errorMessage)

                GlassPrimaryButton(title: "Já confirmei", isWorking: account.isWorking) {
                    Task { await account.confirmAndSignIn(password: password) }
                }
                .disabled(password.isEmpty)

                Button("Voltar", action: account.backToSignIn)
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
    }
}
