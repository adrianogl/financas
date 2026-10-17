# Cadastro de receitas — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cadastrar receitas recorrentes e avulsas, prever valor e data de cada mês, marcar recebimentos e mostrar na home quanto falta receber.

**Architecture:** Funções puras (`BusinessCalendar`, `IncomeSchedule`) calculam as ocorrências de cada mês a partir das receitas, das vigências de valor e dos recebimentos. Só receitas, vigências e recebimentos vão para o Supabase. Um `IncomeStore` (`@MainActor @Observable`) carrega esses dados por um protocolo `IncomeService` (fake nos testes, `SupabaseIncomeService` no app) e alimenta a home e a aba Receitas.

**Tech Stack:** SwiftUI, Swift 6, iOS 26, XcodeGen, `supabase-swift` 2.55.4 (PostgREST), Swift Testing, Postgres com RLS.

**Spec:** `docs/superpowers/specs/2026-10-16-cadastro-de-receitas-design.md`

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift` da pasta da feature.
- Textos da interface em português. Erros específicos, nunca `alert`: confirmação destrutiva com `.confirmationDialog`.
- Dinheiro sempre em `Decimal` no app e `numeric(12,2)` no banco. Nunca `Double`.
- Datas de domínio como dia e mês de calendário (`CalendarDay`, `YearMonth`), sem `Date` nem fuso no banco. "Hoje" vem do calendário e do fuso do aparelho.
- Toda tabela nova com RLS e políticas restritas a `user_id = auth.uid()`. Advisors de segurança sem aviso nas tabelas novas.
- Identidade visual de `Theme.swift`: destaque `Color.accentColor`, `Theme.positive` só em valor positivo, `AppBackground`, cards `.glassEffect(.regular, in: .rect(cornerRadius: 26))`, ícones brancos em círculo de 36 pt.
- Arquivos da feature em `Financas/Income/`; testes em `FinancasTests/`.
- Nunca fazer commit, merge ou push sem aprovação explícita do dono: cada passo "Commit" é propor a mensagem, mostrar `git status`/`git diff --staged` e aguardar. Sem trailer de co-autoria.
- Rodar testes com: `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build` (adicionar `-only-testing:FinancasTests/<Suite>` para uma suíte). Rodar `xcodegen generate` antes, sempre que arquivos forem criados ou removidos.

## Review Focus

1. Valor com centavos (R$ 13.020,04) ida e volta pelo Supabase sem virar 13020.039999 (Task 4: `decodesAmountWithoutPrecisionLoss`, `encodesAmountAsExactNumber`).
2. Sair da conta e entrar com outra: nenhuma receita da conta anterior aparece (Task 5: `resetClearsSnapshot`; Task 6 liga o `reset()` ao `onSignedOut`).
3. Toque duplo em "Marcar como recebida" ou "Salvar": uma request só (Task 5: `ignoresSecondSaveWhileSaving`).
4. Virada de ano: a por hora paga em janeiro de 2027 usa os dias úteis de dezembro de 2026 e o valor da hora vigente em dezembro (Task 2: `januaryRefersToDecemberOfPreviousYear`).
5. Ocorrência que vence hoje é pendente, não atrasada (Task 2: `dueTodayIsPending`).

---

### Task 0: Branch e documentos

O dono já aprovou o desenho. As operações abaixo dependem da aprovação dele, uma a uma.

- [ ] **Step 1: Commit** (com aprovação) de `.gitignore` na branch `chore/ignora-mcp-json`: `chore: ignora .mcp.json no git`. Na mesma alteração, propor também ignorar `.superpowers/` (mockups locais do brainstorming).
- [ ] **Step 2: Merge** (com aprovação) de `chore/ignora-mcp-json` na `main`.
- [ ] **Step 3:** `git checkout main && git checkout -b feat/cadastro-de-receitas`.
- [ ] **Step 4: Commit** (com aprovação) do spec e deste plano: `docs(receitas): adiciona desenho e plano do cadastro de receitas`.

### Task 1: Calendário e dias úteis

**Files:**
- Create: `Financas/Income/CalendarDay.swift`, `Financas/Income/YearMonth.swift`, `Financas/Income/BusinessCalendar.swift`
- Test: `FinancasTests/BusinessCalendarTests.swift`, `FinancasTests/YearMonthTests.swift`

**Interfaces:**
- Produces:
  - `struct CalendarDay: Hashable, Comparable, Codable, Sendable { let year: Int; let month: Int; let day: Int }`, com `init(year:month:day:)`, `init(date: Date, calendar: Calendar = .current)`, `var yearMonth: YearMonth`, `var weekday: Int` (1 = domingo … 7 = sábado, calendário gregoriano), `func adding(days: Int) -> CalendarDay`. Codable como string `"yyyy-MM-dd"`.
  - `struct YearMonth: Hashable, Comparable, Codable, Sendable { let year: Int; let month: Int }`, com `var previous: YearMonth`, `var next: YearMonth`, `var dayCount: Int`, `func day(_ day: Int) -> CalendarDay` (limita ao último dia do mês), `static func range(from: YearMonth, through: YearMonth) -> [YearMonth]` (vazio se `from > through`). Codable como string `"yyyy-MM-01"` (decode aceita qualquer dia e descarta).
  - `enum BusinessCalendar` com `static func easter(in year: Int) -> CalendarDay`, `static func holidays(in year: Int) -> Set<CalendarDay>`, `static func isBusinessDay(_ day: CalendarDay) -> Bool`, `static func businessDayOnOrAfter(_ day: CalendarDay) -> CalendarDay`, `static func businessDays(in month: YearMonth) -> Int`.

- [ ] **Step 1: Testes que falham** em `YearMonthTests`:
  - `previousOfJanuaryIsDecember`: `YearMonth(year: 2027, month: 1).previous == YearMonth(year: 2026, month: 12)`; `YearMonth(year: 2026, month: 12).next == YearMonth(year: 2027, month: 1)`.
  - `dayClampsToLastDay`: `YearMonth(year: 2026, month: 2).day(31) == CalendarDay(year: 2026, month: 2, day: 28)`; `YearMonth(year: 2028, month: 2).day(31).day == 29`.
  - `rangeIsInclusive`: `range(from: 2026-11, through: 2027-01).count == 3`; `range(from: 2026-11, through: 2026-10).isEmpty`.
  - `codesAsDateStrings`: JSON de `CalendarDay(year: 2026, month: 11, day: 3)` é `"2026-11-03"`; `YearMonth(year: 2026, month: 10)` é `"2026-10-01"`; decode de `"2026-10-01"` dá `YearMonth(year: 2026, month: 10)`.
- [ ] **Step 2: Testes que falham** em `BusinessCalendarTests`:
  - `easterDates`: 2026 → 5/4; 2027 → 28/3.
  - `movableHolidays2026`: `holidays(in: 2026)` contém 16/2, 17/2 (Carnaval), 3/4 (Sexta-feira Santa), 4/6 (Corpus Christi).
  - `movableHolidays2027`: contém 8/2, 9/2, 26/3, 27/5.
  - `fixedHolidays`: `holidays(in: 2026)` contém 1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11, 25/12; total de 13 dias.
  - `nextBusinessDay`: 15/11/2026 → 16/11/2026; 1/11/2026 → 3/11/2026; 1/10/2026 → 1/10/2026; 25/12/2026 → 28/12/2026.
  - `businessDaysPerMonth`: setembro/2026 = 21; outubro/2026 = 21; novembro/2026 = 19; fevereiro/2026 = 18.
- [ ] **Step 3:** Rodar `-only-testing:FinancasTests/YearMonthTests -only-testing:FinancasTests/BusinessCalendarTests`. Esperado: falha de compilação.
- [ ] **Step 4: Implementar** os três tipos. Páscoa pelo algoritmo de Meeus/Jones/Butcher. Carnaval = Páscoa − 48 e − 47 dias; Sexta-feira Santa = − 2; Corpus Christi = + 60. Aritmética de dias com `Calendar(identifier: .gregorian)` em UTC, para não depender do fuso.
- [ ] **Step 5:** Rodar as duas suítes. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit** (com aprovação): `feat(receitas): adiciona calendário de dias úteis com feriados nacionais`.

### Task 2: Receitas, ocorrências e resumo do mês

**Files:**
- Create: `Financas/Income/IncomeKind.swift`, `Income.swift`, `IncomeAmount.swift`, `IncomeReceipt.swift`, `IncomeSnapshot.swift`, `OccurrenceStatus.swift`, `IncomeOccurrence.swift`, `MonthSummary.swift`, `IncomeSchedule.swift`
- Test: `FinancasTests/IncomeScheduleTests.swift`, `FinancasTests/IncomeSamples.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `enum IncomeKind: String, Codable, Sendable { case fixed, hourly, oneOff = "one_off" }`
  - `struct Income: Identifiable, Hashable, Codable, Sendable { let id: UUID; var name: String; var kind: IncomeKind; var dayOfMonth: Int?; var hoursPerDay: Decimal?; var startMonth: YearMonth?; var endMonth: YearMonth?; var oneOffDate: CalendarDay?; var oneOffAmount: Decimal? }`. `CodingKeys` em snake_case (`day_of_month`, `hours_per_day`, `start_month`, `end_month`, `one_off_date`, `one_off_amount`). Sem `user_id`: o banco preenche.
  - `struct IncomeAmount: Identifiable, Hashable, Codable, Sendable { let id: UUID; let incomeID: UUID; var amount: Decimal; var validFrom: YearMonth }` (`income_id`, `valid_from`).
  - `struct IncomeReceipt: Identifiable, Hashable, Codable, Sendable { let id: UUID; let incomeID: UUID; let month: YearMonth; var receivedOn: CalendarDay; var amount: Decimal; var workedDays: Int?; var workedHours: Decimal? }` (`income_id`, `received_on`, `worked_days`, `worked_hours`).
  - `struct IncomeSnapshot: Equatable, Sendable { var incomes: [Income]; var amounts: [IncomeAmount]; var receipts: [IncomeReceipt]; static let empty }`
  - `enum OccurrenceStatus: Equatable { case received, overdue, pending }`
  - `struct IncomeOccurrence: Identifiable, Hashable { let income: Income; let month: YearMonth; let referenceMonth: YearMonth?; let dueDate: CalendarDay; let expectedAmount: Decimal; let businessDays: Int?; let hourlyRate: Decimal?; let receipt: IncomeReceipt?; let status: OccurrenceStatus; var id: String }` (`id` = `"\(income.id)-\(month)"`).
  - `struct MonthSummary: Equatable { let received: Decimal; let remaining: Decimal; let expected: Decimal; let overdueCount: Int; let next: IncomeOccurrence? }`
  - `enum IncomeSchedule` com:
    - `static func occurrence(of income: Income, in month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> IncomeOccurrence?`
    - `static func occurrences(in month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence]` (só as do mês, por `dueDate`)
    - `static func overdue(before month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence]` (atrasadas de meses anteriores, desde o `startMonth` de cada recorrente e a data da avulsa, por `dueDate`)
    - `static func summary(for month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> MonthSummary`

Regras (do spec):
- Fixa no mês M: ativa se `startMonth <= M` e (`endMonth == nil` ou `M <= endMonth`). `dueDate = businessDayOnOrAfter(M.day(dayOfMonth))`. Valor: vigência com o maior `validFrom <= M`.
- Por hora paga no mês M: mesma regra de atividade, `referenceMonth = M.previous`, `businessDays = businessDays(in: referenceMonth)`, `hourlyRate` = vigência com o maior `validFrom <= referenceMonth`, `expectedAmount = businessDays × hoursPerDay × hourlyRate`.
- Avulsa: só no mês de `oneOffDate`, `dueDate = oneOffDate` (sem regra de dia útil), valor `oneOffAmount`.
- Sem vigência aplicável: não gera ocorrência.
- Status: com recebimento (`receipt.month == M`) → `.received`; `dueDate < today` → `.overdue`; senão `.pending`.
- Resumo: `received` = soma de `receipt.amount` das recebidas do mês; `remaining` = soma de `expectedAmount` das não recebidas do mês e, se `month == today.yearMonth`, também das de `overdue(before: month)`; `expected = received + remaining`; `overdueCount` conta as atrasadas incluídas em `remaining`; `next` = a não recebida de menor `dueDate` com `dueDate >= today`, procurando no mês e no seguinte.

- [ ] **Step 1: Amostras** em `IncomeSamples.swift` (target de teste): `fixed` (R$ 13.020,04, dia 1, início 2026-10), `hourly` (R$ 90/h vigente desde 2026-09, 8 h/dia, dia 15, início 2026-10) e um `IncomeSnapshot` com as duas.
- [ ] **Step 2: Testes que falham** em `IncomeScheduleTests` (hoje = 16/10/2026 salvo indicação):
  - `fixedInNovember`: fixa em 2026-11 → `dueDate` 3/11/2026, `expectedAmount` 13020.04.
  - `hourlyInNovemberRefersToOctober`: por hora em 2026-11 → `referenceMonth` 2026-10, `businessDays` 21, `expectedAmount` 15120, `dueDate` 16/11/2026.
  - `hourlyInOctoberRefersToSeptember`: em 2026-10 → `businessDays` 21, `expectedAmount` 15120, `dueDate` 15/10/2026, `status == .overdue`.
  - `dueTodayIsPending`: hoje = 15/10/2026 → a por hora de 2026-10 é `.pending`.
  - `receiptMarksReceived`: com recebimento da fixa em 2026-10 → `.received`.
  - `rateChangeKeepsPreviousMonths`: nova vigência de R$ 100 a partir de 2026-11 → por hora de 2026-11 (ref. outubro) = 15120; de 2026-12 (ref. novembro, 19 dias) = 19 × 8 × 100 = 15200.
  - `januaryRefersToDecemberOfPreviousYear`: por hora em 2027-01 → `referenceMonth` 2026-12, valor da hora vigente em dezembro.
  - `skipsMonthWithoutAmount`: por hora com vigência só a partir de 2026-11 → sem ocorrência em 2026-11 (ref. outubro), com ocorrência em 2026-12.
  - `respectsStartAndEnd`: fixa com início 2026-10 e fim 2026-12 → nada em 2026-09 nem em 2027-01.
  - `day31InFebruary`: fixa dia 31 em 2027-02 → `dueDate` = próximo dia útil a partir de 28/2/2027 (domingo) = 1/3/2027.
  - `oneOffOnItsDate`: avulsa em 20/11/2026 (feriado) → ocorrência só em 2026-11, `dueDate` 20/11/2026.
  - `overdueFromSeptemberCarriesToOctober`: snapshot com a por hora começando em 2026-09, vigência desde 2026-08 e sem recebimentos, hoje = 16/10/2026 → `overdue(before: 2026-10)` tem a de 2026-09 (ref. agosto); `summary(for: 2026-10)` soma ela em `remaining` e em `overdueCount`.
  - `summaryOctober`: fixa de 2026-10 recebida com 13020.04, por hora pendente → `received` 13020.04, `remaining` 15120, `expected` 28140.04, `overdueCount` 1, `next?.income == fixed` com `dueDate` 3/11/2026.
  - `summaryUsesReceivedAmount`: fixa recebida com 13000 → `received` 13000, `expected` 28120.
  - `pastMonthHasNoCarryOver`: `summary(for: 2026-09)` não inclui atrasadas de agosto.
- [ ] **Step 3:** Rodar `-only-testing:FinancasTests/IncomeScheduleTests`. Esperado: falha de compilação.
- [ ] **Step 4: Implementar** os tipos e `IncomeSchedule`.
- [ ] **Step 5:** Rodar a suíte. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 6: Commit** (com aprovação): `feat(receitas): calcula ocorrências e resumo do mês`.

### Task 3: Tabelas no Supabase

**Files:**
- Create: `supabase/migrations/20261016120000_create_incomes.sql`

- [ ] **Step 1: Escrever a migration** com:

```sql
create table public.incomes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  kind text not null check (kind in ('fixed', 'hourly', 'one_off')),
  day_of_month smallint check (day_of_month between 1 and 31),
  hours_per_day numeric(5,2) check (hours_per_day > 0),
  start_month date check (extract(day from start_month) = 1),
  end_month date check (extract(day from end_month) = 1),
  one_off_date date,
  one_off_amount numeric(12,2) check (one_off_amount > 0),
  created_at timestamptz not null default now(),
  check (
    (kind = 'fixed' and day_of_month is not null and start_month is not null and hours_per_day is null and one_off_date is null and one_off_amount is null)
    or (kind = 'hourly' and day_of_month is not null and start_month is not null and hours_per_day is not null and one_off_date is null and one_off_amount is null)
    or (kind = 'one_off' and one_off_date is not null and one_off_amount is not null and day_of_month is null and start_month is null and end_month is null and hours_per_day is null)
  ),
  check (end_month is null or end_month >= start_month)
);

create table public.income_amounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  income_id uuid not null references public.incomes(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  valid_from date not null check (extract(day from valid_from) = 1),
  unique (income_id, valid_from)
);

create table public.income_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  income_id uuid not null references public.incomes(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  received_on date not null,
  amount numeric(12,2) not null check (amount >= 0),
  worked_days smallint check (worked_days >= 0),
  worked_hours numeric(6,2) check (worked_hours >= 0),
  unique (income_id, month)
);

create index on public.income_amounts (income_id);
create index on public.income_receipts (income_id);
create index on public.incomes (user_id);
create index on public.income_amounts (user_id);
create index on public.income_receipts (user_id);
```

  Para cada uma das três tabelas: `alter table ... enable row level security;` e quatro políticas `to authenticated` (`select` e `delete` com `using ((select auth.uid()) = user_id)`, `insert` com `with check`, `update` com `using` e `with check` iguais).
- [ ] **Step 2:** Aplicar pelo MCP do Supabase (`apply_migration`, nome `create_incomes`) com o mesmo SQL.
- [ ] **Step 3:** `list_tables` no schema `public` mostra as três tabelas com RLS ligado.
- [ ] **Step 4:** `get_advisors` tipo `security` e tipo `performance`. Esperado: nenhum aviso para `incomes`, `income_amounts` e `income_receipts`.
- [ ] **Step 5: Commit** (com aprovação): `feat(receitas): cria tabelas de receitas com rls`.

### Task 4: Serviço de receitas no Supabase

**Files:**
- Create: `Financas/Shared/SupabaseClientFactory.swift`, `Financas/Income/IncomeService.swift`, `Financas/Income/IncomeError.swift`, `Financas/Income/SupabaseIncomeService.swift`, `Financas/Income/IncomeConstants.swift`
- Modify: `Financas/Account/SupabaseAccountService.swift` (passa a receber o `SupabaseClient`), `Financas/FinancasApp.swift`
- Test: `FinancasTests/IncomeCodingTests.swift`

**Interfaces:**
- Consumes: Task 2 (modelos Codable).
- Produces:
  - `enum SupabaseClientFactory { static func make(config: SupabaseConfig) -> SupabaseClient }` com as mesmas opções de auth que hoje estão no `init` do `SupabaseAccountService`. `SupabaseAccountService.init(client: SupabaseClient)`.
  - `enum IncomeError: Error, Equatable { case network, unknown; var message: String }` — `.network`: "Sem conexão. Verifique a internet e tente de novo."; `.unknown`: "Não foi possível salvar. Tente de novo."
  - `@MainActor protocol IncomeService { func load() async throws(IncomeError) -> IncomeSnapshot; func save(_ income: Income, amount: IncomeAmount?) async throws(IncomeError); func delete(incomeID: UUID) async throws(IncomeError); func save(_ receipt: IncomeReceipt) async throws(IncomeError); func deleteReceipt(id: UUID) async throws(IncomeError) }`
  - `final class SupabaseIncomeService: IncomeService` com `init(client: SupabaseClient)`. `save(_:amount:)` faz upsert da receita e, se houver, upsert da vigência com `onConflict: "income_id,valid_from"`. `save(_ receipt:)` faz upsert com `onConflict: "income_id,month"`. Nomes das tabelas em `IncomeConstants`.
  - `URLError` vira `.network`; qualquer outro erro, `.unknown`.

- [ ] **Step 1: Testes que falham** em `IncomeCodingTests`:
  - `decodesAmountWithoutPrecisionLoss`: `JSONDecoder` em `{"id":"<uuid>","income_id":"<uuid>","amount":13020.04,"valid_from":"2026-10-01"}` → `amount == Decimal(string: "13020.04")!`.
  - `encodesAmountAsExactNumber`: `JSONEncoder` de um `IncomeAmount` com 13020.04 contém `"amount":13020.04`.
  - `decodesIncomeFromRow`: linha de `incomes` com `kind: "hourly"`, `hours_per_day: 8`, `start_month: "2026-10-01"`, `end_month: null` e campos de avulsa nulos → `Income` com `kind == .hourly`, `startMonth == YearMonth(year: 2026, month: 10)`, `endMonth == nil`.
  - `encodesIncomeWithoutUserID`: o JSON de um `Income` não tem a chave `user_id`.
- [ ] **Step 2:** Rodar `-only-testing:FinancasTests/IncomeCodingTests`. Esperado: falha (se algum modelo da Task 2 já passar, o teste continua valendo como regressão). Se o decode de `Decimal` perder precisão, decodificar `amount` a partir do texto do número.
- [ ] **Step 3: Implementar** `SupabaseClientFactory`, `IncomeError`, `IncomeService`, `SupabaseIncomeService`, `IncomeConstants`. Em `FinancasApp.init`, criar o client uma vez com a factory e passar para os dois serviços.
- [ ] **Step 4:** `xcodegen generate` e a suíte inteira. Esperado: `** TEST SUCCEEDED **`, incluindo os testes de conta que já existiam.
- [ ] **Step 5: Commit** (com aprovação): `feat(receitas): adiciona serviço de receitas no supabase`.

### Task 5: IncomeStore e rascunhos

**Files:**
- Create: `Financas/Income/IncomeStore.swift`, `Financas/Income/IncomeLoadState.swift`, `Financas/Income/IncomeDraft.swift`, `Financas/Income/ReceiptDraft.swift`
- Modify: `FinancasTests/Fakes.swift` (novo `FakeIncomeService`)
- Test: `FinancasTests/IncomeStoreTests.swift`, `FinancasTests/IncomeDraftTests.swift`, `FinancasTests/ReceiptDraftTests.swift`

**Interfaces:**
- Consumes: Tasks 1, 2 e 4 (`IncomeService`, `IncomeError`).
- Produces:
  - `enum IncomeLoadState: Equatable { case idle, loading, loaded, failed(String) }`
  - `struct IncomeDraft: Equatable` com `var kind: IncomeKind`, `var name: String`, `var amount: Decimal?`, `var amountValidFrom: YearMonth`, `var dayOfMonth: Int`, `var hoursPerDay: Decimal`, `var startMonth: YearMonth`, `var endMonth: YearMonth?`, `var oneOffDate: CalendarDay`, `let incomeID: UUID?`; `init(today: CalendarDay)` (fixa, dia 1, 8 h, início e vigência no mês de hoje, avulsa em hoje); `init(income: Income, snapshot: IncomeSnapshot, today: CalendarDay)` (valor = vigência atual, `amountValidFrom` = mês de hoje); `var validationMessage: String?`; `func build() -> (Income, IncomeAmount?)`.
  - `struct ReceiptDraft: Equatable` com `var workedDays: Int?`, `var workedHours: Decimal?`, `let hoursPerDay: Decimal?`, `let hourlyRate: Decimal?`, `var receivedOn: CalendarDay`, `var amount: Decimal`; `init(occurrence: IncomeOccurrence, today: CalendarDay)`; `mutating func setWorkedDays(_ days: Int)`; `mutating func setWorkedHours(_ hours: Decimal)`; `var expectedAmount: Decimal`; `func receipt(for occurrence: IncomeOccurrence) -> IncomeReceipt`.
  - `@MainActor @Observable final class IncomeStore` com `init(service: IncomeService, today: @escaping () -> CalendarDay = { CalendarDay(date: .now) })`; `private(set) var snapshot: IncomeSnapshot`; `private(set) var loadState: IncomeLoadState`; `private(set) var isSaving: Bool`; `private(set) var errorMessage: String?`; `var selectedMonth: YearMonth`; `var today: CalendarDay`; `func load() async`; `func reset()`; `func occurrences(in month: YearMonth) -> [IncomeOccurrence]` (no mês atual, atrasadas de meses anteriores primeiro); `func summary(for month: YearMonth) -> MonthSummary`; `var activeRecurring: [Income]`; `var endedRecurring: [Income]`; `func save(_ draft: IncomeDraft) async -> Bool`; `func end(_ income: Income, in month: YearMonth) async -> Bool`; `func delete(_ income: Income) async -> Bool`; `func markReceived(_ occurrence: IncomeOccurrence, with draft: ReceiptDraft) async -> Bool`; `func unmarkReceived(_ occurrence: IncomeOccurrence) async -> Bool`.

Regras:
- `IncomeDraft.validationMessage`: nome vazio (após trim) → "Dê um nome para a receita."; `amount` nil ou ≤ 0 → "Informe um valor maior que zero."; `endMonth < startMonth` → "O mês de fim precisa ser depois do início."; `hoursPerDay` ≤ 0 na por hora → "Informe as horas por dia.".
- `IncomeDraft.build()` numa por hora nova: vigência com `validFrom = startMonth.previous` (o primeiro pagamento paga o mês anterior). Fixa nova: `validFrom = startMonth`. Edição: `validFrom = amountValidFrom`, e a vigência só é gravada se o valor mudou. Avulsa: sem `IncomeAmount`.
- `ReceiptDraft.init`: se a ocorrência tem recebimento, parte dele; senão `workedDays = businessDays`, `workedHours = businessDays × hoursPerDay`, `amount = expectedAmount`, `receivedOn = today`. `setWorkedDays` recalcula horas e valor; `setWorkedHours` recalcula o valor. Alterar dias ou horas sobrescreve o valor recebido.
- `IncomeStore`: ações retornam `false` e não chamam o serviço se `isSaving` já estiver `true`. Em erro, mantêm o `snapshot` e preenchem `errorMessage` com `IncomeError.message`. Em sucesso, atualizam o `snapshot` localmente e limpam `errorMessage`. `reset()` volta a `snapshot = .empty`, `loadState = .idle` e `selectedMonth` ao mês de hoje.

- [ ] **Step 1: `FakeIncomeService`** em `Fakes.swift`: guarda um `IncomeSnapshot`, conta chamadas por método, aceita um `IncomeError?` para a próxima chamada e, opcionalmente, segura a resposta até ser liberado (para o teste de toque duplo).
- [ ] **Step 2: Testes que falham** em `IncomeDraftTests`:
  - `newHourlyStartsRateOneMonthBefore`: por hora, início 2026-10, R$ 90 → `IncomeAmount.validFrom == 2026-09`.
  - `editWithSameAmountWritesNoNewRate`: edição sem mudar o valor → `build().1 == nil`.
  - `validation`: as quatro mensagens acima, uma por caso.
- [ ] **Step 3: Testes que falham** em `ReceiptDraftTests`:
  - `defaultsFromOccurrence`: por hora de 2026-10 → `workedDays` 21, `workedHours` 168, `amount` 15120, `receivedOn` hoje.
  - `changingDaysRecalculates`: `setWorkedDays(20)` → `workedHours` 160, `amount` 14400.
  - `changingHoursRecalculates`: `setWorkedHours(170)` → `amount` 15300.
  - `fixedHasNoHours`: fixa → `workedDays == nil`, `amount` 13020.04.
- [ ] **Step 4: Testes que falham** em `IncomeStoreTests`:
  - `loadsSnapshot`: `load()` → `loadState == .loaded` e `snapshot` igual ao do fake.
  - `loadFailureShowsMessage`: fake com `.network` → `loadState == .failed(IncomeError.network.message)`.
  - `markReceivedUpdatesOccurrence`: com a fixa de 2026-10 já recebida, depois de `markReceived` na por hora de 2026-10, ela fica `.received` e `summary(for: 2026-10).remaining == 0`.
  - `networkErrorKeepsState`: `markReceived` com `.network` → retorna `false`, status continua `.overdue`, `errorMessage == IncomeError.network.message`.
  - `ignoresSecondSaveWhileSaving`: duas chamadas a `markReceived` sem liberar o fake → uma chamada ao serviço.
  - `unmarkReturnsToOverdue`: `unmarkReceived` → `.overdue` de novo.
  - `endKeepsHistory`: `end(fixed, in: 2026-11)` e depois `today = 1/12/2026` → a fixa está em `endedRecurring`, não em `activeRecurring`, e `occurrences(in: 2026-10)` ainda tem a fixa.
  - `currentMonthListsOverdueFirst`: com a por hora de setembro atrasada, `occurrences(in: 2026-10).first?.month == 2026-09`.
  - `resetClearsSnapshot`: depois de `reset()`, `snapshot == .empty` e `loadState == .idle`.
- [ ] **Step 5:** Rodar as três suítes. Esperado: falha de compilação.
- [ ] **Step 6: Implementar** `IncomeLoadState`, `IncomeDraft`, `ReceiptDraft`, `IncomeStore`.
- [ ] **Step 7:** `xcodegen generate` e a suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 8: Commit** (com aprovação): `feat(receitas): adiciona estado das receitas com serviço abstrato`.

### Task 6: Abas, card da home e textos

**Files:**
- Create: `Financas/Income/IncomeFormat.swift`, `Financas/Home/IncomeSummaryCard.swift`, `Financas/Home/AppTab.swift`, `Financas/Home/MainTabView.swift`, `Financas/Income/IncomesView.swift` (placeholder com título "Receitas", substituído na Task 7)
- Modify: `Financas/Shared/Theme.swift` (`warning`), `Financas/Home/HomeView.swift`, `Financas/RootView.swift`, `Financas/FinancasApp.swift`
- Test: `FinancasTests/IncomeFormatTests.swift`

**Interfaces:**
- Consumes: Task 5 (`IncomeStore`, `MonthSummary`).
- Produces:
  - `enum AppTab: Hashable { case home, incomes }`; `MainTabView` com `TabView(selection:)`, `Tab("Início", systemImage: "house", value: .home)` e `Tab("Receitas", systemImage: "arrow.down.circle", value: .incomes)`. `HomeView` recebe `@Binding var selectedTab: AppTab`.
  - `Theme.warning = Color.dynamic(light: 0xC9483B, dark: 0xE8796D)`.
  - `enum IncomeFormat` com `static func monthTitle(_ month: YearMonth) -> String` ("Outubro de 2026"); `static func monthName(_ month: YearMonth) -> String` ("outubro"); `static func shortDate(_ day: CalendarDay) -> String` ("qui, 15 out"); `static func rule(for income: Income, rate: Decimal?) -> String` ("Todo dia 15 · R$ 90/h · 8h/dia", "Todo dia 1 · próximo dia útil"); `static func occurrenceTitle(_ occurrence: IncomeOccurrence) -> String` ("Por hora · setembro" para a por hora, nome para as outras). Todas com `locale: Locale = Locale(identifier: "pt_BR")`.

- [ ] **Step 1: Testes que falham** em `IncomeFormatTests` com os exemplos acima, mais `shortDate(3/11/2026) == "ter, 3 nov"`.
- [ ] **Step 2:** Rodar a suíte. Esperado: falha de compilação.
- [ ] **Step 3: Implementar** `IncomeFormat` e `Theme.warning`.
- [ ] **Step 4: Ligar o store**: `FinancasApp` cria o `IncomeStore` com `SupabaseIncomeService(client:)`, injeta com `.environment` e chama `incomeStore.reset()` dentro do `onSignedOut` já existente. `RootView` troca `HomeView()` por `MainTabView()` e dispara `incomeStore.load()` com `.task(id: lockManager.isUnlocked)` quando desbloqueado.
- [ ] **Step 5: Card da home** `IncomeSummaryCard` entre `balanceCard` e `transactionsCard`, conforme o spec ("Telas › Home"): rótulo "Falta receber em \(monthName)", valor em `.system(size: 26, weight: .semibold)` com `monospacedDigit`, selo "\(n) atrasada(s)" em `Theme.warning` sobre `Theme.warning.opacity(0.12)`, `ProgressView(value:)` com `tint(Theme.accent)`, legenda "R$ X de R$ Y já entrou", linha "Próxima: \(nome) · \(shortDate)". Sem receitas: "Cadastre sua primeira receita" com botão que abre a aba. Carregando: `ProgressView`. Falha: mensagem e "Tentar de novo". Tocar no card: `selectedTab = .incomes` e `selectedMonth` no mês atual. O rótulo "Valores de exemplo" fica logo abaixo dos cards de saldo e lançamentos.
- [ ] **Step 6:** `xcodegen generate`, suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 7: Verificar no simulador**: build e run no iPhone 17, desbloquear, print da home. Esperado: card no lugar e com o visual do mockup (`.superpowers/brainstorm/57707-1792197486/content/receitas-c-identidade.html`), barra de abas com Início e Receitas.
- [ ] **Step 8: Commit** (com aprovação): `feat(receitas): adiciona abas e card de falta receber na home`.

### Task 7: Aba Receitas

**Files:**
- Modify: `Financas/Income/IncomesView.swift`
- Create: `Financas/Income/MonthPicker.swift`, `Financas/Income/IncomeMonthSummaryCard.swift`, `Financas/Income/OccurrenceRow.swift`, `Financas/Income/RecurringIncomeRow.swift`, `Financas/Income/EndedIncomesView.swift`

**Interfaces:**
- Consumes: Tasks 5 e 6 (`IncomeStore`, `IncomeFormat`, `Theme.warning`).
- Produces: `IncomesView` expõe a apresentação de duas sheets usadas nas Tasks 8 e 9: `@State private var editing: IncomeDraft?` (toolbar "+" e toque numa receita cadastrada ou numa avulsa) e `@State private var receiving: IncomeOccurrence?` (toque numa ocorrência não recebida ou recebida). Nesta task, as duas sheets mostram só um texto provisório.

- [ ] **Step 1: Montar a tela** conforme o spec ("Telas › Aba Receitas") e o mockup: `NavigationStack` com título "Receitas", "+" na toolbar, `AppBackground`, `MonthPicker` em vidro (‹ mês ›, ligado a `selectedMonth`), `IncomeMonthSummaryCard` (Recebido em `Theme.positive`, Falta, Previsto), seções "Pendentes" (selo "atrasada" em `Theme.warning`), "Recebidas" (valor em `Theme.positive`, previsto original ao lado quando for diferente) e "Cadastradas" (só no mês atual ou futuro, com o link "Encerradas" para `EndedIncomesView`). Seção vazia não aparece. Carregando e falha como no card da home. `errorMessage` do store aparece abaixo do resumo.
- [ ] **Step 2:** `xcodegen generate`, suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 3: Verificar no simulador** com uma receita criada direto no banco pelo MCP (`execute_sql` com o `user_id` da conta de teste): print da aba em outubro e em novembro de 2026. Apagar a linha depois.
- [ ] **Step 4: Commit** (com aprovação): `feat(receitas): adiciona aba de receitas com resumo e lista do mês`.

### Task 8: Criar, editar, encerrar e excluir receita

**Files:**
- Create: `Financas/Income/IncomeFormView.swift`, `Financas/Income/IncomeFormConstants.swift`
- Modify: `Financas/Income/IncomesView.swift` (sheet de `editing`)

**Interfaces:**
- Consumes: Task 5 (`IncomeDraft`, `IncomeStore.save/end/delete`), Task 7 (`editing`).

- [ ] **Step 1: Formulário** em sheet: `Picker` segmentado com "Fixa", "Por hora", "Avulsa" (rótulos em `IncomeFormConstants`); campos por tipo: nome; valor mensal, valor da hora ou valor (teclado decimal, formato BRL); dia do mês (1 a 31); horas por dia; mês de início e mês de fim opcional; data da avulsa. Na edição de recorrente, "Novo valor a partir de" (mês) aparece só quando o valor muda. `validationMessage` abaixo do formulário e botão de salvar desabilitado enquanto houver mensagem ou `isSaving`. Toolbar com fechar (✕) e confirmar (✓), como no mockup. Fecha quando `save` retorna `true`.
- [ ] **Step 2: Encerrar e excluir** na edição: "Encerrar receita" pede o mês de fim (padrão: mês atual) e chama `end`; "Excluir receita" abre `.confirmationDialog("Excluir receita?", ...)` com "Excluir" destrutivo e a mensagem "Os recebimentos marcados desta receita também serão apagados."
- [ ] **Step 3:** `xcodegen generate`, suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 4: Verificar no simulador**: criar as duas receitas do dono (fixa R$ 13.020,04 dia 1 e por hora R$ 90/h 8 h dia 15, ambas a partir de outubro de 2026); conferir no banco pelo MCP (`execute_sql`) as linhas em `incomes` e `income_amounts`, com a vigência da por hora em 2026-09-01.
- [ ] **Step 5: Commit** (com aprovação): `feat(receitas): adiciona cadastro e edição de receitas`.

### Task 9: Marcar recebida

**Files:**
- Create: `Financas/Income/ReceiptSheet.swift`
- Modify: `Financas/Income/IncomesView.swift` (sheet de `receiving`)

**Interfaces:**
- Consumes: Task 5 (`ReceiptDraft`, `markReceived`, `unmarkReceived`), Task 7 (`receiving`).

- [ ] **Step 1: Sheet** conforme o spec ("Marcar como recebida") e o mockup: título "Marcar recebida", ✕ e ✓ na toolbar, título da ocorrência e valor previsto em destaque, "previsto para \(shortDate)". Por hora: grupo com dias trabalhados (`Stepper`), horas (campo decimal) e valor da hora (só leitura), com a dica "Mude as horas se teve folga, férias ou hora extra." Todas: "Recebido em" (`DatePicker` só data) e "Valor recebido". Botão `GlassPrimaryButton("Marcar como recebida", isWorking: store.isSaving)`. Numa ocorrência já recebida, o botão vira "Salvar" e aparece "Desmarcar recebimento".
- [ ] **Step 2:** `xcodegen generate`, suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 3: Verificar no simulador**: marcar a fixa de outubro e a por hora de outubro (ref. setembro) com 20 dias → resumo de outubro com recebido R$ 27.420,04, falta R$ 0,00, previsto R$ 27.420,04, e a home sem selo de atraso. Desmarcar a por hora → ela volta a atrasada e a falta volta a R$ 15.120,00. Conferir pelo MCP a linha em `income_receipts` com `worked_days = 20` e `worked_hours = 160`.
- [ ] **Step 4: Commit** (com aprovação): `feat(receitas): permite marcar e desmarcar recebimentos`.

### Task 10: Validação real

- [ ] **Step 1:** Rodar a suíte inteira. Esperado: `** TEST SUCCEEDED **`.
- [ ] **Step 2:** Advisors de segurança do Supabase pelo MCP. Esperado: nenhum aviso nas tabelas novas.
- [ ] **Step 3:** No simulador, com as duas receitas do dono a partir de outubro de 2026: home em 16/10/2026 mostra "Falta receber em outubro" com R$ 15.120,00 e "1 atrasada" (se a por hora não foi marcada) e "Próxima: Fixa · ter, 3 nov". Aba em novembro: fixa em 3/11, por hora em 16/11 com 21 dias × 8h.
- [ ] **Step 4:** Segundo simulador (iPad) com a mesma conta: mesmos dados.
- [ ] **Step 5:** Sair da conta e entrar com outra conta de teste: nenhuma receita aparece. Pelo MCP, conferir que essa conta não lê linhas da outra (`select` com `set local role authenticated` e `request.jwt.claims` da segunda conta).
- [ ] **Step 6:** Sem internet: a aba mostra o erro e "Tentar de novo"; com internet de volta, carrega.
