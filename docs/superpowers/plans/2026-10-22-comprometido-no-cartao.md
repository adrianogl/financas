# Comprometido no cartão Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cada usuário conecta os próprios cartões pelo MeuPluggy e vê, numa aba Cartões, quanto já está comprometido nos próximos 12 meses com parcelas e fixos confirmados.

**Architecture:** Duas Edge Functions (Deno) falam com a Pluggy: `cards-connect` (connect token, registro e remoção de item) e `cards-sync` (sincronização diária por `pg_cron` e sob demanda). Elas gravam em quatro tabelas com RLS. O app só lê essas tabelas, grava as decisões de recorrência e o apelido do cartão, e calcula parcelas, fixos e comprometido em tipos Swift puros, como `ExpenseSchedule`. Nenhuma chamada à Pluggy sai do app, exceto o widget Pluggy Connect, que recebe um connect token gerado no servidor.

**Tech Stack:** SwiftUI (iOS 26), Swift 6, Swift Charts, Swift Testing, Supabase (supabase-swift 2.55.4, Postgres com RLS, Edge Functions em Deno, `pg_cron` + `pg_net`), Pluggy API, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-22-comprometido-no-cartao-design.md` (mockups em `docs/superpowers/mockups/2026-10-22-comprometido-no-cartao.html` e `docs/superpowers/mockups/2026-10-22-comprometido-no-cartao-dispositivos.html`).

## Global Constraints

- Sem comentários no código (Swift, SQL e TypeScript).
- Um tipo por arquivo; constantes em `Financas/Cards/CardConstants.swift`; types e constantes das Edge Functions em arquivos próprios em `supabase/functions/_shared/`.
- Textos em PT-BR, exatamente como na spec e nos mockups quando eles fixam o texto.
- `PLUGGY_CLIENT_ID` e `PLUGGY_CLIENT_SECRET` só existem como secrets das Edge Functions. Nada da Pluggy no `Secrets.xcconfig`.
- Endpoint de transações: só `GET /v2/transactions?accountId=&dateFrom=&dateTo=` com cursor (`next`). O v1 retorna 410.
- Widget: `https://cdn.pluggy.ai/pluggy-connect/v2.9.2/pluggy-connect.js`, `connectorIds: [200]` (MeuPluggy).
- Mês de referência de toda transação: mês de `date`. Nunca `billForecastDate` ou `billPostDate`.
- Toda tela e todo teste já existente continua passando; Despesas, Home e saldo do mês não mudam.
- Depois de criar arquivos Swift, rodar `xcodegen generate`.
- Testes Swift: `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination "id=30493143-5FCC-4EE1-9047-DCD0FA3E8597"` (iPhone Air). Se o ID não existir, escolher um iPhone em `xcrun simctl list devices available`.
- Testes das Edge Functions: `deno test supabase/functions` (instalar com `brew install deno` se faltar).
- Execução na branch `feat/comprometido-no-cartao`, criada a partir de `docs/comprometido-no-cartao`. Commit por tarefa em Conventional Commits PT-BR, sem trailer de co-autoria e sem citar IA, só depois de o dono aprovar a mensagem (regra do CLAUDE.md dele). Sem push.
- Nenhum agente aplica migration, faz deploy de Edge Function ou cadastra secret no Supabase. O dono faz isso depois da revisão final.

## Review Focus

1. Usuário com mais de 1.000 transações em 13 meses (C6 sozinho teve 594): o PostgREST corta em 1.000 linhas por request, e o app perderia parcelas e fixos. O load pagina (teste em Task 1).
2. A mesma parcela vinda duas vezes (pendente e depois lançada com outro `id`, ou sync repetido): conta uma vez só (teste em Task 4).
3. Estorno de compra parcelada (`CREDIT` com dados de parcela) e compra cancelada: o `CREDIT` não vira parcela, e a compra sai da projeção pela regra dos 2 meses (teste em Task 4).
4. Conexão removida enquanto o filtro está no cartão dela: o filtro volta para Todos e nada da conexão aparece (teste em Task 6).
5. Compra em moeda estrangeira: o valor gravado é o da moeda do cartão (`amountInAccountCurrency` quando vier), não o valor em USD (teste em Task 2).

---

### Task 1: Banco, modelos e serviço

**Files:**
- Create: `supabase/migrations/20261022000000_create_cards.sql`
- Create: `Financas/Cards/CardConnection.swift`, `CardConnectionStatus.swift`, `CardAccount.swift`, `CardTransaction.swift`, `CardTransactionType.swift`, `CardRecurrence.swift`, `CardRecurrenceStatus.swift`, `CardSnapshot.swift`, `CardService.swift`, `SupabaseCardService.swift`, `CardPaging.swift`, `CardConstants.swift`
- Modify: `FinancasTests/Fakes.swift` (`FakeCardService`)
- Test: `FinancasTests/CardCodingTests.swift`, `FinancasTests/CardPagingTests.swift`, `FinancasTests/CardSamples.swift`

**Interfaces:**
- Produces:
  - `struct CardConnection: Identifiable, Hashable, Codable, Sendable { id: UUID; itemID: String; status: CardConnectionStatus; lastSyncedAt: Date?; lastError: String? }`
  - `enum CardConnectionStatus: String, Codable { case active, needsReconnect = "needs_reconnect", error }`
  - `struct CardAccount: Identifiable, Hashable, Codable, Sendable { id: UUID; connectionID: UUID; name: String; lastDigits: String; nickname: String }`
  - `struct CardTransaction: Identifiable, Hashable, Codable, Sendable { id: String; cardAccountID: UUID; date: CalendarDay; description: String; amount: Decimal; type: CardTransactionType; isPending: Bool; installmentNumber: Int?; totalInstallments: Int?; purchaseDate: CalendarDay? }`
  - `enum CardTransactionType: String, Codable { case debit = "DEBIT", credit = "CREDIT" }`
  - `struct CardRecurrence: Identifiable, Hashable, Codable, Sendable { id: UUID; cardAccountID: UUID; merchantKey: String; status: CardRecurrenceStatus; endedOn: CalendarDay? }`
  - `enum CardRecurrenceStatus: String, Codable { case confirmed, dismissed, ended }`
  - `struct CardSnapshot: Equatable { connections; accounts; transactions; recurrences; static let empty }`
  - `@MainActor protocol CardService { func load(since: CalendarDay) async throws(IncomeError) -> CardSnapshot; func save(_ recurrence: CardRecurrence) async throws(IncomeError); func rename(accountID: UUID, nickname: String) async throws(IncomeError); func sync() async throws(IncomeError); func connectToken(itemID: String?) async throws(IncomeError) -> String; func register(itemID: String) async throws(IncomeError); func remove(connectionID: UUID) async throws(IncomeError) }`
  - `enum CardPaging { static func fetchAll<T>(pageSize: Int, fetch: (Int, Int) async throws -> [T]) async rethrows -> [T] }` (recebe `from` e `to` inclusivos)

- [ ] **Step 1: Escrever a migration**

Tabelas com `user_id uuid not null default auth.uid() references auth.users(id) on delete cascade` e índice em `user_id`, como `20261017040000_create_expenses.sql`:
- `card_connections`: `id`, `item_id text not null unique`, `status text not null default 'active' check (status in ('active','needs_reconnect','error'))`, `last_synced_at timestamptz`, `last_error text`, `created_at`.
- `card_accounts`: `id`, `connection_id` → `card_connections` `on delete cascade`, `pluggy_account_id text not null unique`, `name text not null`, `last_digits text not null`, `nickname text not null check (length(trim(nickname)) > 0)`.
- `card_transactions`: `id text primary key` (id da Pluggy), `card_account_id` → `card_accounts` `on delete cascade`, `date date not null`, `description text not null`, `amount numeric(12,2) not null check (amount >= 0)`, `type text not null check (type in ('DEBIT','CREDIT'))`, `is_pending boolean not null`, `installment_number smallint`, `total_installments smallint`, `purchase_date date`; índice em `(card_account_id, date)`.
- `card_recurrences`: `id`, `card_account_id` → `card_accounts` `on delete cascade`, `merchant_key text not null`, `status text not null check (status in ('confirmed','dismissed','ended'))`, `ended_on date`, `check ((status = 'ended') = (ended_on is not null))`, `unique (card_account_id, merchant_key)`.

RLS: as quatro com `select` do próprio usuário. `card_recurrences` também com `insert` e `update` do próprio usuário. `card_accounts` com `update` do próprio usuário, e um trigger `before update` que rejeita mudança em qualquer coluna além de `nickname`. Escrita no resto só pela service role (Edge Functions).

- [ ] **Step 2: Escrever os testes de coding e paginação que falham**

```swift
@Test func decodesTransactionRow() throws {
    let json = #"{"id":"tx1","card_account_id":"\#(CardSamples.c6.id)","date":"2026-09-08","description":"EBN *PLAYSTATION","amount":112.47,"type":"DEBIT","is_pending":false,"installment_number":3,"total_installments":4,"purchase_date":"2026-06-27"}"#
    let tx = try JSONDecoder().decode(CardTransaction.self, from: Data(json.utf8))
    #expect(tx.date == CalendarDay(year: 2026, month: 9, day: 8))
    #expect(tx.amount == Decimal(string: "112.47"))
    #expect(tx.installmentNumber == 3 && tx.totalInstallments == 4)
    #expect(tx.purchaseDate == CalendarDay(year: 2026, month: 6, day: 27))
}

@Test func encodesRecurrenceWithEndedOn() throws { /* status "ended", ended_on "2026-10-01" no JSON */ }

@Test func fetchAllPagesUntilShortPage() async throws {
    var calls: [(Int, Int)] = []
    let rows = try await CardPaging.fetchAll(pageSize: 1000) { from, to in
        calls.append((from, to))
        return Array(repeating: 0, count: from == 2000 ? 37 : 1000)
    }
    #expect(rows.count == 2037)
    #expect(calls.map(\.0) == [0, 1000, 2000])
    #expect(calls.map(\.1) == [999, 1999, 2999])
}
```

`CardSamples` define `c6` e `caixa` (`CardAccount`), helpers `day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay` e `tx(_ account: CardAccount, _ y: Int, _ m: Int, _ d: Int, _ amount: Decimal, _ description: String, installment: (Int, Int)? = nil, purchase: CalendarDay? = nil, type: CardTransactionType = .debit, pending: Bool = false) -> CardTransaction` (id aleatório) e `today = CalendarDay(year: 2026, month: 10, day: 22)`.

- [ ] **Step 3: Rodar e ver falhar**

Run: o comando de testes Swift. Expected: falha de compilação, tipos `Card*` não existem.

- [ ] **Step 4: Implementar modelos, `CardPaging`, `CardService`, `SupabaseCardService` e `FakeCardService`**

`CodingKeys` em snake_case como `Expense`. `SupabaseCardService.load(since:)` lê as quatro tabelas em paralelo (`async let`), e `card_transactions` com `.gte("date", since)` e `.order("date")`, paginada por `CardPaging.fetchAll(pageSize: 1000)` com `.range(from:to:)`. `save(_:)` faz upsert em `card_recurrences` com `onConflict: "card_account_id,merchant_key"`. `rename` faz update de `nickname`. `sync`, `connectToken`, `register` e `remove` chamam `client.functions.invoke` em `cards-sync` e `cards-connect` (corpo `{"action":"token","itemId":…}`, `{"action":"register","itemId":…}`, `{"action":"remove","connectionId":…}`; o token volta em `{"accessToken": …}`). Erros passam por `SupabaseIncomeService.incomeError(from:)`. Nomes de tabela e de função em `CardConstants`. `FakeCardService` guarda o snapshot e registra as chamadas, como `FakeExpenseService`.

- [ ] **Step 5: `xcodegen generate` e rodar os testes**

Expected: PASS, inclusive todos os testes antigos.

- [ ] **Step 6: Commit** (com aprovação do dono): `feat(cartoes): adiciona tabelas e modelos dos cartões`

---

### Task 2: Edge Function `cards-sync`

**Files:**
- Create: `supabase/functions/_shared/pluggy.ts` (cliente: auth com cache de 100 min, `getItem`, `listCreditAccounts`, `listTransactions` com cursor, `createConnectToken`, `deleteItem`)
- Create: `supabase/functions/_shared/pluggyTypes.ts`, `supabase/functions/_shared/cardRows.ts`, `supabase/functions/_shared/cardConstants.ts`
- Create: `supabase/functions/cards-sync/index.ts`
- Create: `supabase/migrations/20261022000100_schedule_cards_sync.sql`
- Test: `supabase/functions/_shared/cardRows_test.ts`

**Interfaces:**
- Consumes: tabelas da Task 1.
- Produces:
  - `transactionRow(tx: PluggyTransaction, cardAccountId: string): CardTransactionRow`
  - `accountRow(account: PluggyAccount, connectionId: string, existingNickname?: string): CardAccountRow`
  - `connectionStatus(item: PluggyItem): "active" | "needs_reconnect" | "error"`
  - `syncWindow(lastSyncedAt: string | null, today: string): { from: string; to: string }`
  - `PluggyClient` em `pluggy.ts`, usado também pela Task 3.

- [ ] **Step 1: Escrever os testes que falham**

```ts
Deno.test("transactionRow usa o valor na moeda do cartão", () => {
  const row = transactionRow({ ...base, amount: 20, amountInAccountCurrency: 103.4, currencyCode: "USD" }, "acc")
  assertEquals(row.amount, 103.4)
})
Deno.test("transactionRow grava valor absoluto, tipo, pendência e parcela", () => {
  const row = transactionRow({ ...base, amount: -900, type: "CREDIT", status: "PENDING",
    creditCardMetadata: { installmentNumber: 3, totalInstallments: 4, purchaseDate: "2026-06-27T08:01:00.000Z" } }, "acc")
  assertEquals([row.amount, row.type, row.is_pending, row.installment_number, row.total_installments, row.purchase_date],
    [900, "CREDIT", true, 3, 4, "2026-06-27"])
  assertEquals(row.date, base.date.slice(0, 10))
})
Deno.test("accountRow gera apelido com nome e final, e preserva apelido existente", () => {
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO      ", number: "4526" }, "c").nickname, "BANDEIRADO ····4526")
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO", number: "4526" }, "c", "C6").nickname, "C6")
})
Deno.test("connectionStatus", () => {
  assertEquals(connectionStatus({ status: "LOGIN_ERROR" }), "needs_reconnect")
  assertEquals(connectionStatus({ status: "WAITING_USER_INPUT" }), "needs_reconnect")
  assertEquals(connectionStatus({ status: "OUTDATED" }), "error")
  assertEquals(connectionStatus({ status: "UPDATED" }), "active")
})
Deno.test("syncWindow: 12 meses na primeira vez, 7 dias antes do último sync depois", () => {
  assertEquals(syncWindow(null, "2026-10-22"), { from: "2025-10-22", to: "2026-10-22" })
  assertEquals(syncWindow("2026-10-21T06:10:00Z", "2026-10-22"), { from: "2026-10-14", to: "2026-10-22" })
})
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `deno test supabase/functions`. Expected: FAIL, módulo `cardRows.ts` não existe.

- [ ] **Step 3: Implementar `cardRows.ts`, `pluggy.ts` e `cards-sync/index.ts`**

`index.ts` aceita dois chamadores. Header `x-cron-secret` igual ao secret `CARDS_CRON_SECRET`: sincroniza todas as conexões. JWT de usuário (`supabase.auth.getUser`): só as conexões dele. Opcionalmente, um `connectionId` no corpo, usado pela Task 3 logo após registrar. Para cada conexão: `getItem` → `status` com `connectionStatus`; `listCreditAccounts` → upsert em `card_accounts` por `pluggy_account_id`, preservando `nickname`; transações da `syncWindow` → upsert em `card_transactions` por `id`; grava `last_synced_at` e limpa `last_error`. Uma exceção numa conexão grava `last_error`, e a função segue para a próxima. Usa a service role (`SUPABASE_SERVICE_ROLE_KEY`).

- [ ] **Step 4: Escrever o agendamento**

`20261022000100_schedule_cards_sync.sql`: `create extension if not exists pg_cron` e `pg_net`; `cron.schedule('cards-sync-daily', '10 9 * * *', …)` (06:10 em Brasília) com `net.http_post` para `<project-url>/functions/v1/cards-sync`, header `x-cron-secret` lido do Vault (`vault.decrypted_secrets` com nome `cards_cron_secret`) e a URL do projeto lida do Vault (`project_url`). Cadastrar os dois valores no Vault fica com o dono, e o arquivo diz isso no nome dos segredos que lê.

- [ ] **Step 5: Rodar os testes**

Run: `deno test supabase/functions` e `deno check supabase/functions/cards-sync/index.ts`. Expected: PASS e sem erro de tipo.

- [ ] **Step 6: Commit** (com aprovação do dono): `feat(cartoes): sincroniza transações dos cartões pela pluggy`

---

### Task 3: Edge Function `cards-connect`

**Files:**
- Create: `supabase/functions/cards-connect/index.ts`, `supabase/functions/_shared/itemOwnership.ts`
- Test: `supabase/functions/_shared/itemOwnership_test.ts`

**Interfaces:**
- Consumes: `PluggyClient` (Task 2); a função `cards-sync` com `connectionId`.
- Produces: `ownsItem(item: PluggyItem, userId: string): boolean`, `connectTokenBody(userId: string, itemId?: string): object`; ações `token`, `register` e `remove` usadas por `SupabaseCardService`.

- [ ] **Step 1: Escrever os testes que falham**

```ts
Deno.test("ownsItem só aceita item do mesmo usuário", () => {
  assertEquals(ownsItem({ clientUserId: "u1" } as PluggyItem, "u1"), true)
  assertEquals(ownsItem({ clientUserId: "u2" } as PluggyItem, "u1"), false)
  assertEquals(ownsItem({ clientUserId: null } as PluggyItem, "u1"), false)
})
Deno.test("connectTokenBody amarra o usuário e, na reconexão, o item", () => {
  assertEquals(connectTokenBody("u1"), { clientUserId: "u1" })
  assertEquals(connectTokenBody("u1", "it"), { clientUserId: "u1", itemId: "it" })
})
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `deno test supabase/functions`. Expected: FAIL.

- [ ] **Step 3: Conferir na documentação da Pluggy o formato de `clientUserId`**

Confirmar em docs.pluggy.ai se `clientUserId` vai na raiz do corpo de `POST /connect_token` ou dentro de `options`, e que `GET /items/{id}` devolve `clientUserId` (o probe confirmou que o campo existe no item). Ajustar `connectTokenBody` e o teste se a doc disser outro formato.

- [ ] **Step 4: Implementar `itemOwnership.ts` e `cards-connect/index.ts`**

A função exige o JWT do usuário. As ações:
- `token`: chama `POST /connect_token` com `connectTokenBody` e devolve `{ accessToken }`. Na reconexão, antes confere se o `itemId` é de uma conexão do usuário.
- `register`: faz `getItem`, e com `ownsItem` falso devolve 403 sem gravar. Faz upsert em `card_connections` por `item_id` e chama `cards-sync` com `connectionId`.
- `remove`: confere o dono, chama `deleteItem`, ignorando 404, e apaga a linha de `card_connections`. O cascade apaga contas, transações e recorrências.

- [ ] **Step 5: Rodar os testes**

Run: `deno test supabase/functions` e `deno check supabase/functions/cards-connect/index.ts`. Expected: PASS.

- [ ] **Step 6: Commit** (com aprovação do dono): `feat(cartoes): conecta e remove bancos pelo meupluggy`

---

### Task 4: Parcelas

**Files:**
- Create: `Financas/Cards/MerchantKey.swift`, `InstallmentPlan.swift`, `InstallmentPlans.swift`
- Test: `FinancasTests/MerchantKeyTests.swift`, `FinancasTests/InstallmentPlansTests.swift`

**Interfaces:**
- Consumes: `CardTransaction`, `YearMonth`, `CalendarDay`.
- Produces:
  - `enum MerchantKey { static func make(_ description: String) -> String }`
  - `struct InstallmentPlan: Hashable { cardAccountID: UUID; name: String; purchaseDate: CalendarDay; installmentAmount: Decimal; totalInstallments: Int; lastSeenNumber: Int; lastSeenMonth: YearMonth; var lastMonth: YearMonth; var releasesIn: YearMonth; func amount(in month: YearMonth) -> Decimal }`
  - `enum InstallmentPlans { static func plans(from: [CardTransaction], today: CalendarDay) -> [InstallmentPlan] }`

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func merchantKeyStripsInstallmentAndPunctuation() {
    #expect(MerchantKey.make("MAGALU PARC 03/10") == "MAGALU")
    #expect(MerchantKey.make("EBN    *PLAYSTATION    CURITIB") == "EBN PLAYSTATION CURITIB")
    #expect(MerchantKey.make("Açaí da Esquina") == "ACAI DA ESQUINA")
    #expect(MerchantKey.make("WELLHUB ADRIANO GONCAL SAO PAULO BRA") != MerchantKey.make("WELLHUB CRISTIANO GONC SAO PAULO BRA"))
}

@Test func playStationIsOnePurchaseWithOneLeft() {
    let june27 = CardSamples.day(2026, 6, 27)
    let txs = [
        CardSamples.tx(CardSamples.c6, 2026, 6, 27, 112.49, "EBN *PLAYSTATION", installment: (1, 4), purchase: june27),
        CardSamples.tx(CardSamples.c6, 2026, 8, 5, 112.47, "EBN *PLAYSTATION", installment: (2, 4), purchase: june27),
        CardSamples.tx(CardSamples.c6, 2026, 9, 8, 112.47, "EBN *PLAYSTATION", installment: (3, 4), purchase: june27),
    ]
    let plans = InstallmentPlans.plans(from: txs, today: CardSamples.today)
    #expect(plans.count == 1)
    #expect(plans[0].installmentAmount == Decimal(string: "112.47"))
    #expect(plans[0].lastMonth == YearMonth(year: 2026, month: 10))
    #expect(plans[0].releasesIn == YearMonth(year: 2026, month: 11))
    #expect(plans[0].amount(in: YearMonth(year: 2026, month: 10)) == Decimal(string: "112.47"))
    #expect(plans[0].amount(in: YearMonth(year: 2026, month: 11)) == 0)
}

@Test func installmentMonthIsTransactionDateMonth() { /* parcela com date 2026-04-02: amount(in: abril) > 0; projeção começa em maio */ }

@Test func sameInstallmentTwiceCountsOnce() { /* duas transações 2/10 da mesma compra com ids diferentes (uma pending, outra posted): plans.count == 1, lastSeenNumber == 2 */ }

@Test func creditWithInstallmentDataIsIgnored() { /* CREDIT 2/10 sozinho: plans vazio */ }

@Test func planDropsWhenNextInstallmentMissingTwoMonths() {
    /* última vista 2/10 em julho/2026, today 22/10/2026 (setembro e outubro sem a 3/10): plans vazio.
       Mesma compra com 2/10 em agosto: continua (só setembro faltou e outubro ainda corre). */
}
```

- [ ] **Step 2: Rodar e ver falhar**

- [ ] **Step 3: Implementar**

`MerchantKey.make`: tira acento, passa para maiúsculas, remove `\b(PARC(ELA)?\s*)?\d{1,2}\s*/\s*\d{1,2}\b`, troca o que não é letra ou dígito por espaço e junta os espaços. A chave da compra é cartão + `purchaseDate` + `totalInstallments` + `MerchantKey`. Entram só `DEBIT` com `totalInstallments >= 2` e `purchaseDate`. Por compra, uma linha por `installmentNumber`, ficando a de maior `date`. `name` é a descrição da última parcela vista, com o sufixo de parcela tirado. `lastMonth = lastSeenMonth + (total − lastSeenNumber)`. A compra sai da lista quando `today.yearMonth >= lastSeenMonth.next.next.next` e `lastSeenNumber < total`. `amount(in:)` devolve `installmentAmount` para os meses de `lastSeenMonth.next` até `lastMonth`, e também para meses já vistos, e 0 fora disso.

- [ ] **Step 4: Rodar os testes** — Expected: PASS.

- [ ] **Step 5: Commit** (com aprovação do dono): `feat(cartoes): agrupa e projeta compras parceladas`

---

### Task 5: Recorrências e fixos

**Files:**
- Create: `Financas/Cards/RecurrenceCandidate.swift`, `RecurrenceDetector.swift`, `FixedCharge.swift`, `FixedCharges.swift`
- Test: `FinancasTests/RecurrenceDetectorTests.swift`, `FinancasTests/FixedChargesTests.swift`

**Interfaces:**
- Consumes: `MerchantKey`, `CardTransaction`, `CardRecurrence`.
- Produces:
  - `struct RecurrenceCandidate: Hashable, Identifiable { cardAccountID: UUID; merchantKey: String; name: String; monthCount: Int; typicalAmount: Decimal; chargedAfterEnd: Bool; var id: String }`
  - `enum RecurrenceDetector { static func candidates(from: [CardTransaction], decisions: [CardRecurrence], today: CalendarDay) -> [RecurrenceCandidate] }`
  - `struct FixedCharge: Hashable, Identifiable { recurrence: CardRecurrence; name: String; amount: Decimal; lastChargedOn: CalendarDay; isStale: Bool; var id: UUID }`
  - `enum FixedCharges { static func charges(from: [CardTransaction], recurrences: [CardRecurrence], today: CalendarDay) -> [FixedCharge] }`

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func wellhubSixMonthsIsCandidate() { /* 6 meses, R$ 183,30: 1 candidato, monthCount 6, typicalAmount 183.30 */ }
@Test func amountsOverTenPercentAreNotCandidate() { /* 100, 100, 120 em 3 meses: vazio */ }
@Test func twoMonthsIsNotCandidate() { /* vazio */ }
@Test func installmentsPendingAndCreditsAreIgnored() { /* parcelas, pendentes e CREDIT não contam meses */ }
@Test func dismissedNeverReturns() { /* Gelateria 3 meses, ~R$ 51 + decisão dismissed: vazio */ }
@Test func confirmedIsNotCandidate() { /* decisão confirmed: vazio */ }
@Test func endedReturnsOnlyAfterNewCharge() {
    /* ended em 2026-09-01; última cobrança 2026-08-10: vazio.
       Nova cobrança 2026-10-10: 1 candidato com chargedAfterEnd == true */
}
@Test func fixedChargeUsesLastAmountAndFlagsStale() {
    /* confirmed; cobranças 40,90 em jul e 44,90 em set; today 22/10: amount 44.90, isStale false.
       Última cobrança em 2026-09-06 (46 dias): isStale true */
}
@Test func endedIsNotFixed() { /* ended: charges vazio */ }
```

- [ ] **Step 2: Rodar e ver falhar**

- [ ] **Step 3: Implementar**

O candidato considera `DEBIT`, não pendente e sem parcela (`totalInstallments` nil ou < 2), com `date` nos 12 meses até `today`, agrupado por cartão + `MerchantKey`. Precisa de 3 ou mais meses distintos e de todos os valores dentro de ±10% da mediana. `typicalAmount` é a mediana, e `name` é a descrição mais recente. A decisão é procurada por `(cardAccountID, merchantKey)`. `isStale` vale quando `today` está mais de 45 dias depois de `lastChargedOn`. Limites (12, 3, 0.10, 45) em `CardConstants`.

- [ ] **Step 4: Rodar os testes** — Expected: PASS.

- [ ] **Step 5: Commit** (com aprovação do dono): `feat(cartoes): detecta recorrências e calcula fixos`

---

### Task 6: Comprometido, filtro e store

**Files:**
- Create: `Financas/Cards/CommitmentMonth.swift`, `CardCommitment.swift`, `CardFilter.swift`, `CardStore.swift`
- Test: `FinancasTests/CardCommitmentTests.swift`, `FinancasTests/CardStoreTests.swift`

**Interfaces:**
- Consumes: Tasks 1, 4 e 5.
- Produces:
  - `struct CommitmentMonth: Hashable, Identifiable { month: YearMonth; installments: Decimal; fixed: Decimal; var total: Decimal; var id: YearMonth }`
  - `enum CardCommitment { static func months(plans: [InstallmentPlan], fixed: [FixedCharge], from: YearMonth, count: Int) -> [CommitmentMonth]; static func ending(_ plans: [InstallmentPlan], today: CalendarDay) -> [InstallmentPlan] }`
  - `enum CardFilter: Hashable { case all; case account(UUID) }`
  - `@MainActor @Observable final class CardStore` com `snapshot`, `loadState: IncomeLoadState`, `filter: CardFilter`, `errorMessage: String?`, `today: CalendarDay`; `load()`, `refresh() async -> Bool` (chama `service.sync()` e depois `load()`), `reset()`; derivados `accounts`, `plans`, `fixedCharges`, `candidates`, `months` (12 a partir de `today.yearMonth.next`), `ending`, `reviewCount: Int`, `oldestSync: Date?`; ações `decide(_ candidate: RecurrenceCandidate, isFixed: Bool)`, `end(_ charge: FixedCharge)`, `rename(_ account: CardAccount, to: String)`, `connectToken(for: CardConnection?) async -> String?`, `register(itemID: String)`, `remove(_ connection: CardConnection)`.

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func monthsStackInstallmentsAndFixed() {
    /* plano 112,47 com lastMonth nov/26 e fixo 999,90: months(from: nov/26, count: 12)
       nov: installments 112.47, fixed 999.90, total 1112.37; dez: installments 0, fixed 999.90; count 12 */
}
@Test func endingIsLastMonthWithinNextThree() {
    /* today out/26: lastMonth nov/26 e jan/27 entram, ordenados por lastMonth; fev/27 não entra; out/26 entra */
}
@Test func filterLimitsEverything() { /* filter .account(c6): plans, fixed, candidates e months só do C6 */ }
@Test func removedAccountResetsFilter() {
    /* filter .account(c6); load devolve snapshot sem o c6: filter == .all, nenhum plano do c6 */
}
@Test func decideConfirmedSavesAndRemovesCandidate() { /* FakeCardService recebe CardRecurrence .confirmed; reviewCount cai 1 */ }
@Test func endSavesEndedWithToday() { /* status .ended, endedOn == today */ }
@Test func loadAsksThirteenMonths() { /* since == 2025-09-01 para today 2026-10-22 */ }
```

- [ ] **Step 2: Rodar e ver falhar**

- [ ] **Step 3: Implementar**

`ending` devolve os planos com `lastMonth` de `today.yearMonth` até 3 meses à frente, inclusive. O fixo entra em todos os meses de `months`. `load(since:)` usa o primeiro dia de `today.yearMonth` menos 13 meses. O padrão de geração e o tratamento de erro seguem `ExpenseStore`: `generation` e `loadFailedMessage` em `CardConstants` ("Não foi possível carregar seus cartões. Tente de novo."). Uma decisão salva com erro desfaz a mudança local e preenche `errorMessage`.

- [ ] **Step 4: Rodar os testes** — Expected: PASS.

- [ ] **Step 5: Commit** (com aprovação do dono): `feat(cartoes): calcula o comprometido por mês`

---

### Task 7: Aba Cartões

**Files:**
- Create: `Financas/Cards/CardsView.swift`, `CardsPanelCard.swift`, `CommitmentChart.swift`, `CardFilterBar.swift`, `CardEndingList.swift`, `CardFixedList.swift`, `CardInstallmentsView.swift`, `CardFixedChargesView.swift`, `RecurrenceReviewBanner.swift`, `RecurrenceReviewSheet.swift`, `CardsEmptyState.swift`, `CardFormat.swift`
- Modify: `Financas/Home/AppTab.swift`, `AppTab+Display.swift`, `AppSectionView.swift`, `MainTabView.swift`, `Financas/Shared/SidebarCounts.swift`, `Financas/Home/AppSidebar.swift` (se o contador não vier de `SidebarCounts`), `Financas/FinancasApp.swift`, `Financas/RootView.swift`
- Test: `FinancasTests/SidebarCountsTests.swift`, `FinancasTests/CardFormatTests.swift`, `FinancasTests/AppNavigationTests.swift` (se depender de `allCases`)

**Interfaces:**
- Consumes: `CardStore` (Task 6).
- Produces: `AppTab.cards`; `SidebarCounts(incomes:expenses:overdue:cards:)` com `cards: Int`; `CardFormat.endingText(_ plan:) -> String` ("4/4 em novembro"), `CardFormat.releasesText(_ plan:) -> String` ("libera em dez"), `CardFormat.syncText(_ date: Date?, now: Date) -> String` ("Atualizado hoje, 06:10", "Atualizado ontem", "Atualizado em 12/10").

- [ ] **Step 1: Escrever os testes que falham**

`SidebarCountsTests`: o mesmo teste de hoje passando `cards: 3` e esperando `counts.cards == 3`. `CardFormatTests`: os três textos acima, com as datas exatas.

- [ ] **Step 2: Rodar e ver falhar**

- [ ] **Step 3: Implementar navegação e ligação do store**

`AppTab`: `case cards` entre `expenses` e `overdue`, com título "Cartões" e ícone `creditcard`. `AppSectionView` mostra `CardsView()`. `MainTabView` lê `CardStore` do environment e passa `reviewCount` em `SidebarCounts`. A barra lateral mostra o contador de Cartões como Receitas e Despesas mostram os delas. `FinancasApp` cria `CardStore(service: SupabaseCardService(client: client))`, injeta com `.environment` e chama `reset()` no `onSignedOut`. `RootView` inclui `cardStore.load()` (não `refresh`, para não disparar sync) junto do refresh atual e no `NSCalendarDayChanged`.

- [ ] **Step 4: Implementar a tela**

Seguir o mockup A e o de dispositivos. De cima para baixo: `RecurrenceReviewBanner` (só com `reviewCount > 0`, texto "N recorrências para revisar", ou "1 recorrência para revisar", e os três primeiros nomes), `CardFilterBar` (Todos + apelidos), `CardsPanelCard` ("Comprometido em <mês>", total, pílulas parcelas/fixos, `CommitmentChart` com Swift Charts e `BarMark` empilhado, parcelas em `Theme.accent` e fixos num roxo novo em `Theme`), "Terminando" (`CardEndingList`, "Ver parcelas (N)" → `CardInstallmentsView`) e "Fixos" (`CardFixedList` com os dois maiores, "Ver todos (N)" → `CardFixedChargesView`, que tem a ação "Encerrar" por linha e o selo "sem cobrança recente"). Conexão com `needsReconnect` ou sem sync há mais de 3 dias mostra uma linha de aviso no topo ("<apelido> sem atualizar desde 12/10" ou "<apelido> precisa reconectar"), que leva a Cartões conectados. `.refreshable { await store.refresh() }`. Sem conexão nenhuma: `CardsEmptyState` ("Nenhum cartão conectado", o texto do mockup e o botão "Conectar banco", que abre a tela da Task 8). `RecurrenceReviewSheet`: uma linha por candidato com cartão, "N meses · ~R$ X", os botões "É fixo" e "Não é fixo", e "cobrado depois de encerrado" quando `chargedAfterEnd`.

Layout por `LayoutMode`: `.compact` em uma coluna; `.regularLandscape` em duas colunas (banner, filtro e painel à esquerda; Terminando e Fixos à direita, com 6 fixos); `.regularPortrait` com painel na largura toda e, embaixo, duas colunas (Terminando + "Outras parcelas" | Fixos com 8). No regular, "Atualizado …" (`CardFormat.syncText(store.oldestSync, …)`) fica ao lado do título.

- [ ] **Step 5: Rodar testes, build e conferir no simulador**

Run: os testes Swift. Expected: PASS. Depois, rodar o app no iPhone Air e no iPad Pro 11 (horizontal e vertical) com um `FakeCardService` populado com `CardSamples` num preview, e comparar com os mockups.

- [ ] **Step 6: Commit** (com aprovação do dono): `feat(cartoes): adiciona a aba cartões`

---

### Task 8: Cartões conectados

**Files:**
- Create: `Financas/Cards/CardConnectionsView.swift`, `CardConnectionRow.swift`, `ConnectBankIntroView.swift`, `PluggyConnectView.swift`, `PluggyConnectPage.swift`, `PluggyConnectEvent.swift`
- Modify: `Financas/Settings/SettingsView.swift`
- Test: `FinancasTests/PluggyConnectEventTests.swift`, `FinancasTests/PluggyConnectPageTests.swift`

**Interfaces:**
- Consumes: `CardStore.connectToken(for:)`, `register(itemID:)`, `remove(_:)`, `rename(_:to:)`.
- Produces: `enum PluggyConnectEvent: Equatable { case success(itemID: String); case error; case close; static func parse(_ body: Any) -> PluggyConnectEvent? }`; `enum PluggyConnectPage { static func html(token: String, itemID: String?) -> String }`.

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func parsesSuccess() { #expect(PluggyConnectEvent.parse(["event": "success", "itemId": "abc"]) == .success(itemID: "abc")) }
@Test func parsesCloseAndError() { /* "close" → .close, "error" → .error, lixo → nil */ }
@Test func pageEmbedsTokenOnlyMeuPluggyAndWidgetVersion() {
    let html = PluggyConnectPage.html(token: "tok\"</script>", itemID: nil)
    #expect(html.contains("pluggy-connect/v2.9.2/pluggy-connect.js"))
    #expect(html.contains("connectorIds: [200]"))
    #expect(!html.contains("tok\"</script>"))
}
@Test func pageSendsUpdateItemOnReconnect() { /* itemID "it1" → html contém updateItem e "it1" */ }
```

- [ ] **Step 2: Rodar e ver falhar**

- [ ] **Step 3: Implementar**

`PluggyConnectPage.html` monta a página com o script do widget e inicializa `PluggyConnect` com `connectToken`, `connectorIds: [200]` e, na reconexão, `updateItem`. Os callbacks `onSuccess`, `onError` e `onClose` mandam `{event, itemId}` para `window.webkit.messageHandlers.pluggy`. Token e item entram por `JSONEncoder`, nunca por interpolação crua. `PluggyConnectView` é um `UIViewRepresentable` de `WKWebView`: carrega a página com `loadHTMLString(_:baseURL: URL(string: "https://connect.pluggy.ai"))`, traduz as mensagens com `PluggyConnectEvent.parse` e devolve o evento num closure.

`CardConnectionsView` (Configurações › "Cartões conectados", nova `Section` "Cartões" no `SettingsView`, antes de "Avisos") segue o mockup. O texto do topo é "Os cartões chegam pelo MeuPluggy, que usa o Open Finance. Os dados atualizam uma vez por dia." Cada linha mostra o apelido, o nome e o final do cartão e o status ("Atualizado hoje", "Atualizado ontem", "Precisa reconectar", em verde, cinza e vermelho), com "Reconectar" quando `needsReconnect`. Tocar no cartão abre a edição do apelido. "Remover" fica no swipe e pede confirmação: "Remover <apelido>? Os dados desse cartão saem do app." Embaixo, o botão "＋ Conectar banco" leva a `ConnectBankIntroView`, que tem os três passos do mockup, "Criar conta no MeuPluggy ↗" (abre `https://meu.pluggy.ai`) e "Continuar". "Continuar" pede o token e abre `PluggyConnectView` em sheet. No `success`, chama `register(itemID:)` e volta para a lista. Erros aparecem como no `SettingsView` (`Theme.warning`, rodapé).

- [ ] **Step 4: Rodar os testes** — Expected: PASS.

- [ ] **Step 5: Teste manual de ponta a ponta (depende do dono aplicar migrations, secrets e deploy)**

Com o dono, num aparelho: conectar o C6 pelo MeuPluggy, ver a conexão em Cartões conectados e a aba preenchida depois do sync, trocar o apelido para "C6", revisar uma recorrência, remover a conexão e ver a aba vazia. Conferir as parcelas de setembro/2026 contra a soma manual nos snapshots do probe.

- [ ] **Step 6: Commit** (com aprovação do dono): `feat(cartoes): adiciona a área de cartões conectados`
