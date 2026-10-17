import SwiftUI

struct AccountView: View {
    @Environment(AccountManager.self) private var account

    @State private var mode: AccountMode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showsForgotPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AppMark(size: 56)
                    .padding(.top, 24)
                Text(mode.title)
                    .font(.largeTitle.bold())

                Picker("Modo", selection: $mode) {
                    ForEach(AccountMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .signUp {
                    GlassTextField(title: "Nome", text: $name, contentType: .name, capitalization: .words)
                }
                GlassTextField(title: "E-mail", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                GlassTextField(
                    title: "Senha (mínimo de \(AccountConstants.minimumPasswordLength) caracteres)",
                    text: $password,
                    contentType: mode == .signUp ? .newPassword : .password,
                    isSecure: true
                )

                AccountErrorText(message: account.errorMessage)

                GlassPrimaryButton(title: mode.label, isWorking: account.isWorking) {
                    Task { await submit() }
                }
                .disabled(!canSubmit)

                if mode == .signIn {
                    Button("Esqueci minha senha") {
                        showsForgotPassword = true
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .animation(.smooth, value: mode)
        .sheet(isPresented: $showsForgotPassword) {
            ForgotPasswordView(email: email)
        }
    }

    private var canSubmit: Bool {
        let hasName = mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return hasName && !email.isEmpty && !password.isEmpty
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await account.signIn(email: email, password: password)
        case .signUp:
            await account.signUp(name: name, email: email, password: password)
        }
    }
}
