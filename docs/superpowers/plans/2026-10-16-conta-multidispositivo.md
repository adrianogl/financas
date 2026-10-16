# Conta no Supabase — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conta com e-mail e senha no Supabase antes do desbloqueio local, para usar o Finanças em vários aparelhos.

**Architecture:** Um `AccountManager` (`@MainActor @Observable`) dono do estado da conta, falando com o Supabase por um protocolo `AccountService` (fake nos testes, `SupabaseAccountService` no app). O `RootView` decide primeiro pela conta e só depois pelo `LockManager`, que ganha dois pontos de entrada: começar logo após o login e zerar ao sair da conta.

**Tech Stack:** SwiftUI, Swift 6, iOS 26, XcodeGen, `supabase-swift` 3.x (SPM), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-16-conta-multidispositivo-design.md`

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift`.
- Textos da interface em português; mensagens de erro específicas.
- Nunca guardar a chave service role no app. Só URL e chave publicável, vindas de `Config/Secrets.xcconfig` (fora do git).
- Senha com no mínimo 8 caracteres.
- Esquema de URL `financas`, redirect `financas://auth-callback`.
- PIN continua local por aparelho; "Sair da conta" apaga sessão, PIN e contadores.
- Erro de rede nunca tira o usuário do app nem apaga o PIN.
- Nunca fazer commit sem aprovação explícita do dono: cada passo "Commit" é propor a mensagem, mostrar `git status`/`git diff --staged` e aguardar. Sem trailer de co-autoria.
- Rodar testes com: `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build` (adicionar `-only-testing:FinancasTests/<Suite>` para uma suíte). Rodar `xcodegen generate` antes, sempre que arquivos forem criados ou removidos.

## Review Focus

1. Abrir o app sem internet com o token vencido: continua dentro, PIN mantido (teste em Task 2: `staysSignedInWhenServiceHasNoEvents` e `networkErrorOnSignInKeepsState`).
2. Criar conta com e-mail já cadastrado: o Supabase não acusa erro (proteção contra enumeração) e o app mostra "Confirme seu e-mail"; o "Já confirmei" com senha errada deve mostrar "E-mail ou senha incorretos." e continuar na tela de confirmação (Task 2: `confirmWithWrongPasswordStaysAwaiting`).
3. Link de redefinição expirado ou aberto em outro aparelho: mensagem clara e volta para a tela de conta (Task 2: `invalidRecoveryLinkShowsMessage`).
4. Toque duplo em "Entrar"/"Criar conta": só uma requisição (Task 2: `ignoresSecondRequestWhileWorking`).
5. E-mail com espaços ou maiúsculas: enviado aparado e em minúsculas (Task 2: `normalizesEmail`).

---

### Task 0: Registrar o estado atual

O repositório não tem commits; todo o trabalho de bloqueio está na branch `feat/tela-de-bloqueio`.

- [ ] **Step 1:** Rodar a suíte inteira. Esperado: `** TEST SUCCEEDED **`, 33 testes.
- [ ] **Step 2: Commit** (com aprovação) de tudo, mensagem `feat: adiciona desbloqueio por biometria e pin, home inicial e ícone do app`. Depois criar a branch `feat/conta-supabase` a partir dela.

### Task 1: SDK e configuração

**Files:**
- Modify: `project.yml`, `.gitignore`
- Create: `Config/Secrets.example.xcconfig`, `Financas/Account/SupabaseConfig.swift`, `Financas/Account/SupabaseConfigError.swift`, `Financas/Account/AccountConstants.swift`
- Test: `FinancasTests/SupabaseConfigTests.swift`

**Interfaces:**
- Produces: `struct SupabaseConfig { let url: URL; let key: String; init(info: [String: Any]) throws(SupabaseConfigError) }`; `enum SupabaseConfigError: Error, Equatable { case missingURL, missingKey }`; `enum AccountConstants` com `redirectURL = URL(string: "financas://auth-callback")!`, `minimumPasswordLength = 8`, `installMarkerKey = "install.v2"`, `legacyNameKey = "profile.name"`, `nameMetadataKey = "name"`, `urlInfoKey = "SupabaseURL"`, `keyInfoKey = "SupabaseKey"`.

- [ ] **Step 1: Testes que falham** em `SupabaseConfigTests`:
  - `readsURLAndKey`: `info = ["SupabaseURL": "https://abc.supabase.co", "SupabaseKey": "pk"]` → `url.absoluteString == "https://abc.supabase.co"`, `key == "pk"`.
  - `missingURLThrows`: `["SupabaseKey": "pk"]` → lança `.missingURL`; `["SupabaseURL": "", "SupabaseKey": "pk"]` → `.missingURL`.
  - `missingKeyThrows`: `["SupabaseURL": "https://abc.supabase.co"]` → `.missingKey`.
- [ ] **Step 2:** Rodar `-only-testing:FinancasTests/SupabaseConfigTests`. Esperado: falha de compilação (`SupabaseConfig` não existe).
- [ ] **Step 3: Implementar** `SupabaseConfig`, `SupabaseConfigError`, `AccountConstants`.
- [ ] **Step 4: Configuração do projeto**:
  - `project.yml`: `packages: Supabase: { url: https://github.com/supabase/supabase-swift, from: "<última tag 3.x>" }` (conferir a tag no GitHub/context7); dependência `- package: Supabase, product: Supabase` no target `Financas`; `configFiles: { Debug: Config/Secrets.xcconfig, Release: Config/Secrets.xcconfig }` no target; em `info.properties`: `SupabaseURL: $(SUPABASE_URL)`, `SupabaseKey: $(SUPABASE_KEY)`, `CFBundleURLTypes: [{ CFBundleURLName: dev.aglv.financas.auth, CFBundleURLSchemes: [financas] }]`.
  - `Config/Secrets.example.xcconfig` com `SUPABASE_URL = https:/$()/SEU-PROJETO.supabase.co` e `SUPABASE_KEY = sua-chave-publicavel`. O `/$()/` é obrigatório: em xcconfig, `//` inicia comentário.
  - `.gitignore`: adicionar `Config/Secrets.xcconfig`.
  - Para rodar localmente antes do Supabase existir: `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig`.
- [ ] **Step 5:** `xcodegen generate` e rodar a suíte. Esperado: SPM resolve o pacote, `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit** (com aprovação): `chore: adiciona sdk do supabase e configuração por xcconfig`.

### Task 2: AccountManager com fake

**Files:**
- Create: `Financas/Account/AccountUser.swift`, `AccountState.swift`, `AccountError.swift`, `AccountEvent.swift`, `SignOutScope.swift`, `AccountService.swift`, `AccountManager.swift` (todos em `Financas/Account/`)
- Test: `FinancasTests/AccountManagerTests.swift`, `FinancasTests/Fakes.swift` (adicionar `FakeAccountService`)

**Interfaces:**
- Produces:
  - `struct AccountUser: Equatable, Sendable { let id: String; let email: String; let name: String }`
  - `enum AccountState: Equatable { case loading, signedOut, awaitingConfirmation(email: String), recoveringPassword(AccountUser), signedIn(AccountUser) }`
  - `enum AccountError: Error, Equatable { case invalidCredentials, emailNotConfirmed, emailAlreadyRegistered, weakPassword, invalidRecoveryLink, network, unknown; var message: String }`
  - `enum AccountEvent: Equatable { case signedOut, passwordRecovery(AccountUser) }`
  - `enum SignOutScope { case local, others }`
  - `@MainActor protocol AccountService { func currentUser() -> AccountUser?; func events() -> AsyncStream<AccountEvent>; func signUp(name: String, email: String, password: String) async throws(AccountError) -> AccountUser?; func signIn(email: String, password: String) async throws(AccountError) -> AccountUser; func sendPasswordReset(email: String) async throws(AccountError); func handle(url: URL) async throws(AccountError); func updatePassword(_ password: String) async throws(AccountError); func signOut(scope: SignOutScope) async }`. `signUp` retorna `nil` quando o e-mail precisa de confirmação.
  - `@MainActor @Observable final class AccountManager` com `private(set) var state: AccountState`, `private(set) var isWorking: Bool`, `private(set) var errorMessage: String?`, `var userName: String?` (nome do `.signedIn`), `init(service: AccountService, defaults: UserDefaults = .standard, hasDevicePIN: @escaping () -> Bool, onAuthenticated: @escaping () -> Void, onSignedOut: @escaping () -> Void)`, e os métodos `start() async`, `signUp(name:email:password:) async`, `signIn(email:password:) async`, `confirmAndSignIn(password:) async`, `backToSignIn()`, `sendPasswordReset(email:) async -> Bool`, `handle(url:) async`, `saveNewPassword(_:) async`, `signOut() async`.

Mensagens de `AccountError.message` (texto exato):
- `invalidCredentials`: "E-mail ou senha incorretos."
- `emailNotConfirmed`: "Confirme seu e-mail antes de entrar. O link está na sua caixa de entrada."
- `emailAlreadyRegistered`: "Já existe uma conta com esse e-mail. Entre com ela."
- `weakPassword`: "A senha precisa ter pelo menos 8 caracteres."
- `invalidRecoveryLink`: "O link expirou ou foi aberto em outro aparelho. Peça um novo neste aparelho."
- `network`: "Sem conexão. Verifique a internet e tente de novo."
- `unknown`: "Algo deu errado. Tente de novo."

Regras do `AccountManager`:
- `start()`: se `defaults` não tem `installMarkerKey` → `await service.signOut(scope: .local)`, remove `legacyNameKey`, chama `onSignedOut()`, grava o marcador, estado `.signedOut`. Senão, se `currentUser()` existe e `hasDevicePIN()` é falso → `signOut(.local)`, `onSignedOut()`, `.signedOut`. Senão `.signedIn(user)` ou `.signedOut`. Depois escuta `events()`: `.signedOut` → `onSignedOut()` e `.signedOut`; `.passwordRecovery(user)` → `.recoveringPassword(user)`.
- E-mail sempre aparado e em minúsculas antes de ir ao serviço; nome aparado.
- `signUp`/`signIn` com senha abaixo de 8 caracteres: `errorMessage = AccountError.weakPassword.message`, sem chamar o serviço.
- Enquanto `isWorking`, novas chamadas são ignoradas.
- `signIn` com sucesso → `.signedIn(user)` e `onAuthenticated()`. `signUp` retornando `nil` → `.awaitingConfirmation(email:)`; retornando usuário → igual ao `signIn`.
- `confirmAndSignIn(password:)` usa o e-mail de `.awaitingConfirmation`; em erro mantém o estado e mostra a mensagem.
- `handle(url:)` com erro → `errorMessage = invalidRecoveryLink.message`, estado `.signedOut`.
- `saveNewPassword` (só em `.recoveringPassword`): `updatePassword`, depois `signOut(scope: .others)`, depois `.signedIn(user)` e `onAuthenticated()`.
- `signOut()`: `signOut(scope: .local)`, `onSignedOut()`, `.signedOut`.
- Qualquer erro `.network` mantém o estado atual.

- [ ] **Step 1: `FakeAccountService`** em `Fakes.swift`: guarda `storedUser`, filas de resultado por método, registra chamadas (`signInCalls: [(String, String)]`, `signOutScopes: [SignOutScope]`, `updatedPasswords`) e expõe `send(_ event:)` que alimenta o `AsyncStream`.
- [ ] **Step 2: Testes que falham** em `AccountManagerTests` (helper cria o manager com `UserDefaults(suiteName: UUID)` já marcado, salvo onde o teste diz o contrário, e contadores de `onAuthenticated`/`onSignedOut`):
  - `freshInstallDiscardsSessionAndLegacyName`: defaults sem marcador, com `profile.name = "X"`, `storedUser` presente → após `start()`: `signOutScopes == [.local]`, `onSignedOut` 1 vez, `state == .signedOut`, nome removido, marcador gravado.
  - `restoresSignedInUser`: marcador presente, `storedUser`, `hasDevicePIN = true` → `.signedIn(user)`, `onSignedOut` 0.
  - `restoredSessionWithoutPINIsDiscarded`: `storedUser`, `hasDevicePIN = false` → `.signedOut`, `signOutScopes == [.local]`.
  - `staysSignedInWhenServiceHasNoEvents`: restaurado e nenhum evento → continua `.signedIn`.
  - `serverSignOutEventSignsOut`: após `start()`, `send(.signedOut)` → `.signedOut`, `onSignedOut` 1.
  - `signInSucceeds`: `.signedIn(user)`, `onAuthenticated` 1.
  - `normalizesEmail`: `signIn(email: "  Eu@Mail.COM ", ...)` → `signInCalls.first?.0 == "eu@mail.com"`.
  - `shortPasswordIsRejectedLocally`: senha `"1234567"` → `errorMessage == weakPassword.message`, `signInCalls.isEmpty`.
  - `wrongPasswordShowsMessage`: serviço lança `.invalidCredentials` → mensagem exata, `.signedOut`.
  - `networkErrorOnSignInKeepsState`: lança `.network` → estado inalterado, mensagem de rede.
  - `ignoresSecondRequestWhileWorking`: duas chamadas concorrentes de `signIn` com o fake suspenso → `signInCalls.count == 1`.
  - `signUpNeedingConfirmationWaits`: `signUp` retorna `nil` → `.awaitingConfirmation(email: "eu@mail.com")`.
  - `confirmWithWrongPasswordStaysAwaiting`: em `.awaitingConfirmation`, `signIn` lança `.invalidCredentials` → continua `.awaitingConfirmation`, mensagem exata.
  - `recoveryEventOpensNewPassword`: `send(.passwordRecovery(user))` → `.recoveringPassword(user)`.
  - `invalidRecoveryLinkShowsMessage`: `handle(url:)` lança → `.signedOut`, mensagem `invalidRecoveryLink`.
  - `newPasswordSignsOutOtherDevices`: em `.recoveringPassword(user)`, `saveNewPassword("novasenha1")` → `updatedPasswords == ["novasenha1"]`, `signOutScopes == [.others]`, `.signedIn(user)`, `onAuthenticated` 1.
  - `signOutClearsEverything`: `signOutScopes == [.local]`, `onSignedOut` 1, `.signedOut`.
- [ ] **Step 3:** Rodar `-only-testing:FinancasTests/AccountManagerTests`. Esperado: falha de compilação.
- [ ] **Step 4: Implementar** os tipos e o `AccountManager` conforme as regras.
- [ ] **Step 5:** Rodar a suíte. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit** (com aprovação): `feat(conta): adiciona estado da conta com serviço abstrato`.

### Task 3: LockManager ligado à conta

**Files:**
- Modify: `Financas/Lock/LockManager.swift`, `Financas/Lock/KeychainPINStore.swift`, `Financas/Lock/LockConstants.swift`
- Test: `FinancasTests/LockManagerTests.swift`, `FinancasTests/KeychainPINStoreTests.swift`

**Interfaces:**
- Produces: `func beginAfterAccountLogin()` e `func resetForSignOut()` no `LockManager`.
- Consumes: nada novo.

- [ ] **Step 1: Testes que falham** em `LockManagerTests`:
  - `afterLoginWithoutPINGoesToSetupWithoutBiometry`: `FakePINStore()` → `beginAfterAccountLogin()` → `needsSetup == true`, `authenticator.passcodeAllowances.isEmpty`.
  - `afterLoginWithPINGoesHome`: com PIN → `phase == .unlocked`, `!needsSetup`, `!shouldAutoUnlock`.
  - `signOutResetClearsPIN`: com PIN e `failedAttempts = 3` → `resetForSignOut()` → `pinStore.pin == nil`, `!hasPIN`, `phase == .locked`, `!shouldAutoUnlock`, `lockedUntil == nil`.
- [ ] **Step 2:** Rodar `-only-testing:FinancasTests/LockManagerTests`. Esperado: falha de compilação.
- [ ] **Step 3: Implementar**: `beginAfterAccountLogin()` vai para `.unlocked` e desliga o auto desbloqueio; `resetForSignOut()` chama `pinStore.clear()`, zera `hasPIN`, `lockedUntil`, mensagens, e vai para `.locked` sem auto desbloqueio. Remover `discardPINFromPreviousInstall()` e `LockConstants.installMarkerKey` do `KeychainPINStore` (a limpeza de instalação agora é do `AccountManager.start()` via `onSignedOut`).
- [ ] **Step 4:** Rodar a suíte. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** (com aprovação): `feat(bloqueio): começa após login e zera ao sair da conta`.

### Task 4: SupabaseAccountService

**Files:**
- Create: `Financas/Account/SupabaseAccountService.swift`

**Interfaces:**
- Consumes: `AccountService`, `AccountError`, `AccountEvent`, `AccountUser`, `SupabaseConfig`, `AccountConstants`.
- Produces: `@MainActor final class SupabaseAccountService: AccountService { init(config: SupabaseConfig) }`.

Antes de escrever, consultar a API do `supabase-swift` 3.x no context7 (`/supabase/supabase-swift`): `signUp(email:password:data:redirectTo:)`, `signIn(email:password:)`, `resetPasswordForEmail(_:redirectTo:)`, `session(from:)`, `update(user:)`, `signOut(scope:)`, `authStateChanges`, `currentUser`.

- [ ] **Step 1: Implementar**:
  - `SupabaseClient(supabaseURL: config.url, supabaseKey: config.key)`; sessão no Keychain padrão do SDK.
  - `AccountUser` a partir de `User`: `id.uuidString`, `email ?? ""`, `userMetadata[AccountConstants.nameMetadataKey]` como string (vazio se ausente).
  - `signUp` envia o nome em `data: [nameMetadataKey: .string(name)]` e `redirectTo: AccountConstants.redirectURL`; retorna `nil` quando a resposta não traz sessão.
  - `events()`: mapeia `authStateChanges`: `.signedOut` → `.signedOut`; `.passwordRecovery` com sessão → `.passwordRecovery(user)`; o resto é ignorado (o `AccountManager` só reage a esses dois). Nunca emitir `.signedOut` por falha de rede.
  - `handle(url:)`: `session(from: url)`; erro → `.invalidRecoveryLink`.
  - `signOut(scope:)`: `.local`/`.others` do SDK; erros ignorados (sessão local sai mesmo sem rede).
  - Mapeamento de erro: código `invalid_credentials` → `.invalidCredentials`; `email_not_confirmed` → `.emailNotConfirmed`; `user_already_exists`/`email_exists` → `.emailAlreadyRegistered`; `weak_password` → `.weakPassword`; `URLError` → `.network`; resto → `.unknown`.
- [ ] **Step 2:** `xcodegen generate` e build. Esperado: `** BUILD SUCCEEDED **` sem warnings novos.
- [ ] **Step 3: Commit** (com aprovação): `feat(conta): implementa serviço de conta com supabase`.

### Task 5: Telas e roteamento

**Files:**
- Create: `Financas/Account/AccountView.swift` (entrar/criar), `AccountMode.swift`, `ConfirmEmailView.swift`, `ForgotPasswordView.swift`, `NewPasswordView.swift`, `GlassTextField.swift` (campo com Liquid Glass reutilizado), `LoadingView.swift`
- Modify: `Financas/FinancasApp.swift`, `Financas/RootView.swift`, `Financas/Setup/SetupView.swift`, `Financas/Setup/SetupStep.swift`, `Financas/Home/HomeView.swift`
- Delete: `Financas/Shared/ProfileConstants.swift`

**Interfaces:**
- Consumes: `AccountManager` (Task 2), `LockManager.beginAfterAccountLogin()`/`resetForSignOut()` (Task 3), `SupabaseAccountService` (Task 4), `SupabaseConfig`.

- [ ] **Step 1: `FinancasApp`**: em `init()`, criar `LockManager` e depois `AccountManager(service: SupabaseAccountService(config:), hasDevicePIN: { lock.hasPIN }, onAuthenticated: { lock.beginAfterAccountLogin() }, onSignedOut: { lock.resetForSignOut() })`, ambos em `@State`. Config inválida → `fatalError` com "Configure Config/Secrets.xcconfig". Injetar os dois com `.environment`. `.task { await account.start() }` e `.onOpenURL { url in Task { await account.handle(url: url) } }`.
- [ ] **Step 2: `RootView`** decide por `account.state`: `.loading` → `LoadingView` (fundo + `AppMark`); `.signedOut` → `AccountView`; `.awaitingConfirmation` → `ConfirmEmailView`; `.recoveringPassword` → `NewPasswordView`; `.signedIn` → o roteamento atual do `LockManager`.
- [ ] **Step 3: Telas da conta** (visual: `AppBackground`, `AppMark` no topo, campos com `.glassEffect`, botão principal `.glassProminent`, erros em `.footnote` abaixo dos campos, botões desabilitados com `isWorking`):
  - `AccountView`: seletor "Entrar" / "Criar conta" (`AccountMode`). Criar pede nome, e-mail, senha; entrar pede e-mail, senha e tem "Esqueci minha senha" (abre `ForgotPasswordView` em sheet). `textContentType` `.name`, `.emailAddress`, `.password`/`.newPassword`.
  - `ConfirmEmailView`: "Confirme seu e-mail", o endereço, campo de senha e botão "Já confirmei" (`confirmAndSignIn`), mais "Voltar" (`backToSignIn`).
  - `ForgotPasswordView`: e-mail, botão "Enviar link"; em sucesso mostra "Enviamos um link para <e-mail>. Abra o link neste aparelho."
  - `NewPasswordView`: nova senha e confirmação; senhas diferentes mostram "As senhas não conferem." sem chamar o serviço.
- [ ] **Step 4: Setup sem nome**: `SetupStep` fica com `createPIN` e `confirmPIN`; remover o passo de nome, `@AppStorage` e `ProfileConstants`.
- [ ] **Step 5: Home**: cumprimento usa `account.userName ?? ""`. A toolbar troca o botão por um `Menu` (ícone `person.crop.circle`) com "Bloquear" (`lock.lock()`) e "Sair da conta", que abre `.confirmationDialog("Sair da conta?", ...)` com "Sair" destrutivo chamando `account.signOut()`. Mensagem do diálogo: "O PIN deste aparelho será apagado. Para voltar, entre com seu e-mail e senha."
- [ ] **Step 6:** `xcodegen generate`, rodar a suíte. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 7: Commit** (com aprovação): `feat(conta): adiciona telas de conta e liga ao desbloqueio`.

### Task 6: Projeto no Supabase e validação real

Feito junto com o dono, que cria o projeto.

- [ ] **Step 1:** Guiar o dono: criar projeto no Supabase; em Authentication > URL Configuration, adicionar `financas://auth-callback` às Redirect URLs; manter "Confirm email" ligado; copiar Project URL e a chave publicável para `Config/Secrets.xcconfig`.
- [ ] **Step 2:** Validar no simulador: criar conta → tela de confirmação → confirmar pelo e-mail → "Já confirmei" → criar PIN → home com o nome → fechar e abrir (só biometria/PIN) → "Sair da conta" → tela de conta.
- [ ] **Step 3:** Segundo simulador com a mesma conta: entra, cria outro PIN, vê o mesmo nome.
- [ ] **Step 4:** "Esqueci minha senha" no simulador 1: link abre o app → nova senha → home. No simulador 2, ao reabrir após a renovação do token, volta para a tela de conta.
- [ ] **Step 5:** Modo avião com sessão válida: o app abre normalmente com biometria/PIN.
- [ ] **Step 6:** Instalar no iPhone e repetir os passos 2 e 5.
