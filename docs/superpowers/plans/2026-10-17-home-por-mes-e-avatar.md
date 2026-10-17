# Home por mês e avatar — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home com seletor de mês e saldo, falta receber e lançamentos reais do mês; avatar com inicial ou foto guardada no Supabase Storage.

**Architecture:** `HomeMonthSummary` (função pura) calcula saldo, gráfico e lançamentos a partir do `IncomeSnapshot`. O avatar fica num `AvatarStore` (`@MainActor @Observable`) que fala com o Storage por um protocolo `AvatarService` e guarda a foto no aparelho com `AvatarCache`. A versão da foto vive em `user_metadata.avatar_version`, lida e atualizada pelo `AccountManager`.

**Tech Stack:** SwiftUI, Swift 6, iOS 26, XcodeGen, `supabase-swift` 2.55.4 (Auth, Storage), PhotosUI, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-17-home-por-mes-e-avatar-design.md`

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift`. Textos em português.
- Dinheiro em `Decimal`; datas de domínio em `CalendarDay`/`YearMonth`.
- Bucket `avatars` privado; caminho `\(user_id)/avatar.jpg`; foto 512 × 512 JPEG qualidade 0,8.
- Commits liberados na branch `feat/home-por-mes-e-avatar` com as mensagens do plano. Migration, merge e push pedem aprovação do dono. Sem trailer de co-autoria.
- Testes: `.superpowers/sdd/<plano>/t.sh [Suites...]` (xcodegen + xcodebuild test no iPhone 17), saída com código real.

## Review Focus

1. Recebimento de outubro pago em 3/11 entra no saldo e nos lançamentos de novembro, não de outubro (Task 1: `paidInNovemberCountsInNovember`).
2. Sair da conta com a foto em cache e entrar com outra: a foto anterior não aparece (Task 3: `resetClearsImageAndCache`; Task 4 liga ao `onSignedOut`).
3. Sem internet ao desbloquear: avatar mostra a foto do cache e `refreshUser` não tira ninguém da conta (Task 3: `downloadFailureKeepsCachedImage`; Task 2: `refreshUserNetworkErrorKeepsUser`).
4. Foto enviada no iPhone aparece no iPad no próximo desbloqueio (Task 3: `newVersionDownloadsAgain`; Task 5 manual).
5. Toque duplo em "Escolher foto" enquanto envia: um upload só (Task 3: `ignoresSecondUploadWhileUploading`).

---

### Task 0: Branch e documentos

- [ ] **Step 1:** `git checkout -b feat/home-por-mes-e-avatar main`; commit do spec e deste plano: `docs(home): adiciona desenho e plano da home por mês e do avatar`.

### Task 1: Resumo do mês na home

**Files:**
- Create: `Financas/Home/HomeMonthSummary.swift`, `Financas/Home/HomeEntry.swift`
- Modify: `Financas/Home/BalancePoint.swift` (vira `Equatable`)
- Test: `FinancasTests/HomeMonthSummaryTests.swift`

**Interfaces:**
- Produces:
  - `struct HomeEntry: Identifiable, Equatable { let id: UUID; let title: String; let kind: IncomeKind; let receivedOn: CalendarDay; let amount: Decimal }` (`id` = id do recebimento; `title` = nome, ou "\(nome) · \(mês de referência)" na por hora, referência = `receipt.month.previous`).
  - `struct HomeMonthSummary: Equatable { let month: YearMonth; let balance: Decimal; let points: [BalancePoint]; let entries: [HomeEntry]; static func make(month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> HomeMonthSummary }`.

Regras: `balance` = soma de `receipt.amount` com `receivedOn <= month.day(month.dayCount)`. `points`: `(1, saldo até o fim do mês anterior)`, depois um ponto por dia com recebimento no mês com o acumulado, depois `(últimoDia, balance)` se `últimoDia` passar do último ponto. `últimoDia` = `today.day` no mês atual, senão `month.dayCount`. `entries` = recebimentos do mês por `receivedOn` decrescente; recebimento de receita que não está no snapshot é ignorado.

- [ ] **Step 1: Testes que falham** (snapshot `IncomeSamples.snapshot` com recebimentos: fixa mês 2026-10 em 1/10 por 13020.04; por hora mês 2026-10 em 16/10 por 14400):
  - `septemberIsEmpty`: mês 2026-09, hoje 20/10 → `balance` 0, `entries` vazio, `points == [(1, 0), (30, 0)]`.
  - `octoberSumsAndOrders`: mês 2026-10, hoje 20/10 → `balance` 27420.04; `entries.map(\.title) == ["Por hora · setembro", "Fixa"]`; `points == [(1, 0), (1, 13020.04), (16, 27420.04), (20, 27420.04)]`.
  - `novemberCarriesBalance`: mês 2026-11, hoje 20/10 → `balance` 27420.04, `entries` vazio, `points == [(1, 27420.04), (30, 27420.04)]`.
  - `paidInNovemberCountsInNovember`: fixa do mês 2026-10 recebida em 3/11 → outubro `balance` 14400 e sem a fixa; novembro `balance` 27420.04 e `entries.first?.receivedOn == 3/11/2026`.
  - `ignoresReceiptOfDeletedIncome`: recebimento com `incomeID` desconhecido não entra em `entries` nem em `balance`.
- [ ] **Step 2:** Rodar `HomeMonthSummaryTests`. Esperado: falha de compilação.
- [ ] **Step 3: Implementar.** `BalancePoint(day: Int, balance: Double)` continua com `Double` para o gráfico; converter com `NSDecimalNumber(decimal:).doubleValue`.
- [ ] **Step 4:** Rodar. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit:** `feat(home): calcula saldo e lançamentos do mês a partir dos recebimentos`.

### Task 2: Home com seletor de mês e dados reais

**Files:**
- Modify: `Financas/Home/HomeView.swift`, `Financas/Home/IncomeSummaryCard.swift`, `Financas/Home/TransactionRow.swift`, `Financas/Home/HomeConstants.swift`, `Financas/Income/ReceiptSheet.swift`, `Financas/Account/AccountService.swift`, `Financas/Account/SupabaseAccountService.swift`, `Financas/Account/AccountUser.swift`, `Financas/Account/AccountManager.swift`, `Financas/Account/AccountConstants.swift`, `Financas/RootView.swift`, `FinancasTests/Fakes.swift`
- Delete: `Financas/Home/SampleTransaction.swift`
- Test: `FinancasTests/AccountManagerTests.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `AccountUser` ganha `var avatarVersion: Int?` (de `user_metadata.avatar_version`, chave em `AccountConstants.avatarVersionMetadataKey = "avatar_version"`).
  - `AccountService` ganha `func refreshUser() async throws(AccountError) -> AccountUser` (`client.auth.user()`) e `func updateAvatarVersion(_ version: Int?) async throws(AccountError) -> AccountUser` (`client.auth.update(user: UserAttributes(data: [key: version.map { .integer($0) } ?? .null]))`).
  - `AccountManager` ganha `func refreshUser() async` (só em `.signedIn`; sucesso troca o usuário do estado; erro é ignorado) e `func apply(_ user: AccountUser)` (só em `.signedIn`).
  - `IncomeStore.selectedMonth` é o mês da home.

- [ ] **Step 1: Testes que falham** em `AccountManagerTests`: `refreshUserUpdatesNameAndAvatar` (fake devolve nome "Novo" e versão 7 → `state == .signedIn(user)` com os dois); `refreshUserNetworkErrorKeepsUser` (fake lança `.network` → estado igual); `refreshUserIgnoredWhenSignedOut`. `FakeAccountService` ganha `refreshedUser`, `refreshError` e `updatedVersions: [Int?]`.
- [ ] **Step 2:** Rodar `AccountManagerTests`. Esperado: falha de compilação.
- [ ] **Step 3: Implementar** os pontos de conta acima e `SupabaseAccountService.accountUser` lendo `avatar_version` (`.integer` ou `.double`).
- [ ] **Step 4: Home:**
  - `MonthPicker(month: $incomeStore.selectedMonth)` logo abaixo do header.
  - Card de saldo: "Saldo até \(IncomeFormat.monthName(mês))", valor `HomeMonthSummary.balance`, gráfico com `points` e domínio Y de `min - 5%` a `max + 5%` (com `max > min`, senão `0...max(1, max)`).
  - `IncomeSummaryCard` usa `selectedMonth` no lugar de `today.yearMonth` e o toque abre a aba sem `showCurrentMonth()`.
  - Card "Lançamentos de \(mês)" com `TransactionRow` adaptado para `HomeEntry` (ícone `kind.systemImage`, tint `Theme.positive`, legenda "Receita · \(dia) \(mês curto)", "+ R$ …"). Vazio: "Nenhum lançamento em \(mês)."
  - Remover `sampleTransactions`, `sampleBalance`, `sampleMonthLabel`, `balancePoints`, `balanceFloor`, `balanceCeiling`, `SampleTransaction` e o rótulo "Saldo e lançamentos com valores de exemplo".
- [ ] **Step 5:** `ReceiptSheet`: `DatePicker(..., in: ...store.today.date(), ...)`.
- [ ] **Step 6:** `RootView`: no `.task(id: lockManager.isUnlocked)`, chamar `await account.refreshUser()` junto com `incomeStore.refresh()`.
- [ ] **Step 7:** Suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 8: Commit:** `feat(home): troca o mês da home e mostra saldo e lançamentos reais`.

### Task 3: Avatar — armazenamento e estado

**Files:**
- Create: `supabase/migrations/20261017020000_create_avatars_bucket.sql`, `Financas/Account/AvatarService.swift`, `Financas/Account/SupabaseAvatarService.swift`, `Financas/Account/AvatarError.swift`, `Financas/Account/AvatarCache.swift`, `Financas/Account/AvatarImageResizer.swift`, `Financas/Account/AvatarStore.swift`, `Financas/Account/AvatarConstants.swift`
- Modify: `FinancasTests/Fakes.swift`
- Test: `FinancasTests/AvatarStoreTests.swift`, `FinancasTests/AvatarImageResizerTests.swift`, `FinancasTests/AvatarCacheTests.swift`

**Interfaces:**
- Consumes: Task 2 (`AccountUser.avatarVersion`, `AccountService.updateAvatarVersion`).
- Produces:
  - `enum AvatarError: Error, Equatable { case network, unknown; var uploadMessage: String; var removeMessage: String }` — "Sem conexão. Verifique a internet e tente de novo." / "Não foi possível enviar a foto. Tente de novo." / "Não foi possível remover a foto. Tente de novo."
  - `@MainActor protocol AvatarService { func upload(_ data: Data, userID: String) async throws(AvatarError); func download(userID: String) async throws(AvatarError) -> Data; func remove(userID: String) async throws(AvatarError) }`
  - `struct AvatarCache { init(directory: URL); func load() -> (version: Int, data: Data)?; func save(_ data: Data, version: Int); func clear() }` (arquivo `avatar.jpg` + `avatar.version` no diretório; padrão: `Caches/avatar`).
  - `enum AvatarImageResizer { static func jpegData(from data: Data) -> Data? }` (corte quadrado central, 512 × 512, escala 1, qualidade 0,8).
  - `@MainActor @Observable final class AvatarStore` com `init(service: AvatarService, cache: AvatarCache, now: @escaping () -> Date = Date.init, updateVersion: @escaping (Int?) async throws(AccountError) -> AccountUser)`; `private(set) var imageData: Data?`; `private(set) var isUploading: Bool`; `private(set) var errorMessage: String?`; `func sync(user: AccountUser) async`; `func upload(_ data: Data, for user: AccountUser) async -> AccountUser?`; `func remove(for user: AccountUser) async -> AccountUser?`; `func reset()`; `static func initial(for user: AccountUser) -> String`.

Regras: `sync` — versão nil → limpa cache e imagem; versão igual à do cache → imagem do cache; diferente → baixa, salva com a versão e mostra; falha no download mantém a imagem atual. `upload` — ignora se `isUploading`; redimensiona; sobe; `updateVersion(Int(now().timeIntervalSince1970))`; salva no cache; devolve o usuário novo. `remove` — apaga o arquivo, `updateVersion(nil)`, limpa cache. Erros preenchem `errorMessage`. `initial` — primeira letra do nome após trim, em maiúscula; sem nome, do e-mail; sem nada, "?".

- [ ] **Step 1: Migration** (aplicar só com aprovação do dono, pelo MCP `apply_migration`, nome `create_avatars_bucket`): bucket `avatars` privado com `file_size_limit = 1048576` e `allowed_mime_types = '{image/jpeg}'`; quatro políticas `to authenticated` em `storage.objects` com `bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text` (`using` em select/update/delete, `with check` em insert/update). Conferir com outro `sub` que `select` em `storage.objects` do dono volta 0 linhas; advisors sem aviso novo.
- [ ] **Step 2: Testes que falham:**
  - `AvatarImageResizerTests.cropsAndResizes`: PNG 1200 × 800 → `UIImage(data:)` com `size == 512 × 512`.
  - `AvatarCacheTests.roundTrips`: save/load/clear num diretório temporário.
  - `AvatarStoreTests`: `initialFromNameOrEmail` ("adriano" → "A"; nome vazio e e-mail "zoe@x" → "Z"); `syncWithoutVersionClearsCache`; `syncUsesCacheWhenVersionMatches` (nenhum download); `newVersionDownloadsAgain`; `downloadFailureKeepsCachedImage`; `uploadSavesAndUpdatesVersion` (versão = `now` fixo); `ignoresSecondUploadWhileUploading`; `uploadFailureShowsMessage`; `removeClearsEverything`; `resetClearsImageAndCache`.
- [ ] **Step 3:** Rodar as três suítes. Esperado: falha de compilação.
- [ ] **Step 4: Implementar.** `SupabaseAvatarService` usa `client.storage.from("avatars")`: `upload("\(userID)/avatar.jpg", data:, options: FileOptions(contentType: "image/jpeg", upsert: true))`, `download(path:)`, `remove(paths:)`. `URLError` → `.network`.
- [ ] **Step 5:** Suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit:** `feat(conta): guarda a foto do avatar no supabase com cache no aparelho`.

### Task 4: Avatar na toolbar

**Files:**
- Create: `Financas/Home/AvatarView.swift`
- Modify: `Financas/Home/HomeView.swift`, `Financas/FinancasApp.swift`, `Financas/RootView.swift`

- [ ] **Step 1:** `AvatarView(initial:imageData:isUploading:size: 36)`: foto em círculo (`scaledToFill`) ou inicial em `Theme.accent` sobre `Theme.markBottom`; `ProgressView` por cima enquanto envia.
- [ ] **Step 2:** Menu da conta com `AvatarView` como label; itens "Escolher foto" (`PhotosPicker`, `.images`), "Remover foto" (só com foto), "Bloquear", "Sair da conta". Ao escolher: `loadTransferable(type: Data.self)` → `avatarStore.upload` → `account.apply(user)`. `avatarStore.errorMessage` em `Theme.warning` abaixo da data do cumprimento.
- [ ] **Step 3:** `FinancasApp` cria `AvatarStore` com `SupabaseAvatarService(client:)`, `AvatarCache` padrão e `updateVersion: { try await accountManager.updateAvatarVersion($0) }` (método novo no `AccountManager` que chama o serviço e aplica o usuário); `onSignedOut` chama `avatarStore.reset()`. `RootView` chama `avatarStore.sync(user:)` sempre que o usuário do `AccountManager` mudar (`.task(id: account.user)`; `AccountManager` ganha `var user: AccountUser?`).
- [ ] **Step 4:** Suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit:** `feat(conta): mostra inicial ou foto no avatar e permite trocar a foto`.

### Task 5: Validação real

- [ ] **Step 1:** Suíte inteira e advisors do Supabase.
- [ ] **Step 2:** Simulador (idb): trocar o mês na home para setembro, outubro e novembro e conferir saldo, falta receber e lançamentos com os recebimentos do banco; a aba Receitas acompanha o mês.
- [ ] **Step 3:** iPhone e iPad físicos (`xcrun devicectl device install app`): enviar foto no iPhone, desbloquear o iPad e ver a mesma foto; remover no iPad e ver a inicial no iPhone depois de desbloquear.
