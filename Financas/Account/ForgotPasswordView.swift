import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AccountManager.self) private var account
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var sentTo: String?

    init(email: String) {
        _email = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                if let sentTo {
                    Text("Enviamos um link para **\(sentTo)**. Abra o link neste aparelho para criar a nova senha.")
                    Spacer()
                    GlassPrimaryButton(title: "Fechar") { dismiss() }
                } else {
                    Text("Digite o e-mail da conta. O link de redefinição só funciona se for aberto neste aparelho.")
                        .foregroundStyle(.secondary)
                    GlassTextField(title: "E-mail", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                    AccountErrorText(message: account.errorMessage)
                    Spacer()
                    GlassPrimaryButton(title: "Enviar link", isWorking: account.isWorking) {
                        Task { await send() }
                    }
                    .disabled(email.isEmpty)
                }
            }
            .padding(24)
            .navigationTitle("Esqueci minha senha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func send() async {
        if await account.sendPasswordReset(email: email) {
            sentTo = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
}
