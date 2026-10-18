# Despesas fixas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cadastro de despesas fixas mensais com estimado pela média, lançamento da conta, pagamento, aba Despesas, home com "Falta pagar", seção na aba Atrasadas e avisos de vencimento.

**Architecture:** Pasta nova `Financas/Expenses/`, no molde de `Financas/Income/`: modelos `Codable` das três tabelas novas, `ExpenseSchedule` (cálculo puro), `ExpenseStore` (`@Observable`) e `ExpenseService` com implementação Supabase e fake. O mês selecionado e o "hoje" continuam no `IncomeStore`; o `ExpenseStore` recebe `today` como parâmetro nas consultas, então home, Receitas e Despesas usam sempre o mesmo mês. Avisos, home e Atrasadas passam a juntar os dois stores.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), Supabase Swift 2.55.4, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-17-despesas-fixas-design.md`

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift`, types em arquivo próprio.
- Textos da interface em português, exatamente como no spec quando ele fixa o texto.
- Vencimento de despesa sempre `BusinessCalendar.businessDayOnOrAfter`, ignorando `AccountSettings.nonBusinessDay`.
- Sem ícones nas linhas de receitas e despesas.
- O app não usa `alert`; confirmações na própria tela, como em `IncomeFormView`.
- Testes com Swift Testing em `FinancasTests/`. Rodar com:
  `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FinancasTests/<Suite> -quiet`
- Arquivo novo exige `xcodegen generate` antes do build.
- Commit só com aprovação explícita do dono (CLAUDE.md). Cada passo "Commit" prepara `git add` e a mensagem proposta; os commits saem juntos no fim, depois da aprovação.
- Migration aplicada no projeto Supabase só depois de aprovação do dono.

## Review Focus

- Vencimento informado ao lançar a conta que cai em outro mês (conta de novembro com vencimento 30/out). Esperado: aparece como atrasada/pendente no mês atual, como as receitas com `previous`. Teste na Task 2.
- Despesa encerrada com mês antigo não pago. Esperado: continua atrasada no mês atual até ser paga. Teste na Task 2.
- Duas edições no mesmo mês (primeiro o estimado, depois só o dia). Esperado: a segunda não muda o início da média nem cria segunda vigência. Teste na Task 3.
- Desmarcar o pagamento de um mês que tinha conta lançada, e remover a conta de um mês pago. Esperado: o outro registro fica. Remover os dois apaga a linha. Teste na Task 4.
- Horário "Atrasadas à noite" igual ao de "Prevista para hoje", ou "Atrasadas à noite" desligado. Esperado: nada de aviso duplicado; desligado não gera o aviso de vence hoje da noite. Teste na Task 7.

---

### Task 1: Tabelas, modelos e serviço

**Files:**
- Create: `supabase/migrations/20261017040000_create_expenses.sql`
- Create: `Financas/Expenses/Expense.swift`, `ExpenseTerm.swift`, `ExpenseBill.swift`, `ExpenseSnapshot.swift`, `ExpenseService.swift`, `SupabaseExpenseService.swift`, `ExpenseConstants.swift`
- Test: `FinancasTests/ExpenseCodingTests.swift`

**Interfaces:**
- Produces:
  - `struct Expense: Identifiable, Hashable, Codable, Sendable { let id: UUID; var name: String; var startMonth: YearMonth; var endMonth: YearMonth? }` — colunas `id, name, start_month, end_month`. `encode` explícito para gravar `end_month` nulo (como `Income`).
  - `struct ExpenseTerm: Identifiable, Hashable, Codable, Sendable { let id: UUID; let expenseID: UUID; var validFrom: YearMonth; var estimatedAmount: Decimal; var dayOfMonth: Int; var averageFrom: YearMonth }` — colunas `expense_id, valid_from, estimated_amount, day_of_month, average_from`.
  - `struct ExpenseBill: Identifiable, Hashable, Codable, Sendable { let id: UUID; let expenseID: UUID; let month: YearMonth; var billAmount: Decimal?; var billDueDate: CalendarDay?; var paidOn: CalendarDay?; var paidAmount: Decimal?; var isEmpty: Bool }` — colunas `expense_id, month, bill_amount, bill_due_date, paid_on, paid_amount`; `isEmpty` é computado (`billAmount == nil && paidAmount == nil`) e fora do `CodingKeys`. `encode` explícito com os nulos.
  - `struct ExpenseSnapshot: Equatable, Sendable { var expenses: [Expense]; var terms: [ExpenseTerm]; var bills: [ExpenseBill]; static let empty }`.
  - `@MainActor protocol ExpenseService { func load() async throws(IncomeError) -> ExpenseSnapshot; func save(_ expense: Expense, term: ExpenseTerm?) async throws(IncomeError); func delete(expenseID: UUID) async throws(IncomeError); func save(_ bill: ExpenseBill) async throws(IncomeError); func deleteBill(id: UUID) async throws(IncomeError) }`.
  - `ExpenseConstants`: `expensesTable = "expenses"`, `termsTable = "expense_terms"`, `billsTable = "expense_bills"`, `loadFailedMessage = "Não foi possível carregar suas despesas. Tente de novo."`.

- [ ] **Step 1: Escrever a migration**

Três tabelas com `id uuid primary key default gen_random_uuid()` e `user_id uuid not null default auth.uid() references auth.users(id) on delete cascade`:
- `expenses`: `name text not null check (length(trim(name)) > 0)`, `start_month date not null`, `end_month date`, checks de dia 1 e `end_month >= start_month`, `created_at`.
- `expense_terms`: `expense_id ... references expenses on delete cascade`, `valid_from date not null`, `estimated_amount numeric(12,2) not null check (> 0)`, `day_of_month smallint not null check (between 1 and 31)`, `average_from date not null`, checks de dia 1, `unique (expense_id, valid_from)`.
- `expense_bills`: `expense_id ...`, `month date not null` (dia 1), `bill_amount numeric(12,2) check (>= 0)`, `bill_due_date date`, `paid_on date`, `paid_amount numeric(12,2) check (>= 0)`, `check ((bill_amount is null) = (bill_due_date is null))`, `check ((paid_on is null) = (paid_amount is null))`, `check (bill_amount is not null or paid_amount is not null)`, `unique (expense_id, month)`.

Índices em `user_id`, RLS ligada, quatro policies por tabela no padrão de `20261016120000_create_incomes.sql`; nos filhos, insert e update já com o `exists` sobre `expenses` de `20261017000000_restrict_income_children_to_owner.sql`.

- [ ] **Step 2: Testes que falham** (`ExpenseCodingTests`)

```swift
@Test func decodesBillWithOnlyPayment() throws // JSON {"id":…,"expense_id":…,"month":"2026-10-01","bill_amount":null,"bill_due_date":null,"paid_on":"2026-10-09","paid_amount":1150} → billAmount nil, paidOn == day(2026,10,9), paidAmount == 1150
@Test func encodesNullBillColumns() throws // bill só com pagamento → JSON contém "bill_amount":null e "bill_due_date":null
@Test func encodesNullEndMonth() throws // Expense sem endMonth → "end_month":null
@Test func decodesTerm() throws // "valid_from":"2026-07-01","average_from":"2026-07-01","day_of_month":13,"estimated_amount":180 → campos certos
```

- [ ] **Step 3: Rodar e ver falhar** — `-only-testing:FinancasTests/ExpenseCodingTests`, esperado: erro de compilação.

- [ ] **Step 4: Implementar modelos, `ExpenseService` e `SupabaseExpenseService`**

`SupabaseExpenseService` segue `SupabaseIncomeService`: `load()` busca as três tabelas em paralelo; `save(_:term:)` faz upsert da despesa e, se houver, do term com `onConflict: "expense_id,valid_from"`; `save(_ bill:)` com `onConflict: "expense_id,month"`; erros por `SupabaseIncomeService.incomeError(from:)`.

- [ ] **Step 5: Rodar `ExpenseCodingTests`** — passa.

- [ ] **Step 6: Commit** — `feat(despesas): cria tabelas, modelos e serviço de despesas`

---

### Task 2: Cálculo das ocorrências

**Files:**
- Create: `Financas/Expenses/ExpenseSchedule.swift`, `ExpenseOccurrence.swift`, `ExpenseStatus.swift`, `ExpenseEstimate.swift`, `ExpenseMonthSummary.swift`
- Test: `FinancasTests/ExpenseSamples.swift`, `FinancasTests/ExpenseScheduleTests.swift`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `enum ExpenseStatus: Hashable { case paid, overdue, pending }`.
  - `enum ExpenseEstimate: Hashable { case average(amount: Decimal, months: [YearMonth]); case manual(Decimal); var amount: Decimal }` — `months` em ordem crescente.
  - `struct ExpenseOccurrence: Identifiable, Hashable { let expense: Expense; let month: YearMonth; let dueDate: CalendarDay; let estimate: ExpenseEstimate; let bill: ExpenseBill?; let status: ExpenseStatus; var amount: Decimal; var hasBill: Bool; var id: String }` — `amount` = `paidAmount ?? billAmount ?? estimate.amount`; `hasBill` = `bill?.billAmount != nil`; `id` = `"\(expense.id)-\(month.year)-\(month.month)"`.
  - `struct ExpenseMonthSummary: Equatable { let paid: Decimal; let remaining: Decimal; let expected: Decimal; let overdueCount: Int; let next: ExpenseOccurrence? }`.
  - `enum ExpenseSchedule` com `static func term(for expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpenseTerm?`, `estimate(for:in:snapshot:) -> ExpenseEstimate?`, `occurrence(of:in:snapshot:today:) -> ExpenseOccurrence?`, `occurrences(in:snapshot:today:) -> [ExpenseOccurrence]`, `overdue(before:snapshot:today:)`, `carried(into:snapshot:today:)`, `summary(for:snapshot:today:) -> ExpenseMonthSummary`.

Regras (do spec):
- `term(for:in:)`: maior `validFrom <= month`; se não houver, o de menor `validFrom`.
- `estimate`: meses `m` com `bill.paidAmount != nil`, `m < month`, `m >= term.averageFrom`; se forem 3 ou mais, média dos `paidAmount` dos 3 mais recentes, arredondada para 2 casas (`NSDecimalRound`, `.plain`); senão `.manual(term.estimatedAmount)`.
- `dueDate`: `bill.billDueDate` quando existe; senão `businessDayOnOrAfter(month.day(term.dayOfMonth))`.
- Ativa em `month` quando `startMonth <= month` e `endMonth.map { month <= $0 } ?? true`.
- `overdue`, `carried`, `summary` com a mesma estrutura de `IncomeSchedule` (inclusive `early(in:)` para vencimento informado no mês anterior). Resumo: `paid` soma `paidAmount` das ocorrências do mês; `remaining` soma `amount` das não pagas (no mês atual, mais as `carried`); `expected = paid + remaining`; `next` = primeira pendente com `dueDate >= today` no mês ou no seguinte.

- [ ] **Step 1: Amostras** — `ExpenseSamples` com `today = day(2026, 10, 17)`, `luz` (início 2026-07, term dia 13, estimado 180, `averageFrom` 2026-07), `internet` (início 2026-10, term dia 26, estimado 180), `condominio` (início 2026-10, dia 10, 1150) e `func paid(_ e: Expense, _ m: YearMonth, _ amount: Decimal, on: CalendarDay) -> ExpenseBill`, `func bill(_ e: Expense, _ m: YearMonth, _ amount: Decimal, due: CalendarDay) -> ExpenseBill`.

- [ ] **Step 2: Testes que falham** (`ExpenseScheduleTests`)

```swift
@Test func dueDateMovesToNextBusinessDay() // luz dia 13 em dez/2026 (domingo) → seg 14/12; condomínio dia 10 em out/2026 (sábado) → seg 12/10
@Test func day31InFebruary() // term dia 31, fev/2027 → último dia útil a partir de 28/02/2027 (domingo) → seg 01/03/2027
@Test func billDueDateReplacesCalculatedOnlyThatMonth() // bill out com due 17/10 → dueDate 17/10; nov continua no calculado
@Test func estimateIsManualWithTwoPaidMonths() // luz paga jul 196.40, ago 201.10 → out .manual(180)
@Test func estimateIsAverageWithThreePaidMonths() // + set 219.80 → out .average(205.77, [jul, ago, set])
@Test func averageUsesThreeMostRecent() // 5 meses pagos → média dos 3 últimos antes do mês
@Test func averageIgnoresMonthsBeforeAverageFrom() // novo term validFrom out, averageFrom nov, estimado 250 → out e nov .manual(250); com nov/dez/jan pagos → fev média deles
@Test func termBeforeEditKeepsOldEstimateAndDay() // term novo em out com dia 20 → set continua dia 13 e estimado antigo
@Test func amountPrefersPaidThenBillThenEstimate()
@Test func statusAndOverdueCarry() // luz set sem pagamento → .overdue; aparece em carried(into: out); some depois de paga
@Test func endedExpenseStillCarriesUnpaidMonth() // luz endMonth set, set não paga → em carried(into: out)
@Test func billDueInPreviousMonthIsCarried() // bill de nov com due 30/10, hoje 31/10 → overdue no mês out
@Test func summaryForOctober() // luz jul–set pagas; out: condomínio pago 1150 em 9/10, luz com conta 212.30 vencida em 13/10, internet 180 → paid 1150, remaining 392.30, expected 1542.30, overdueCount 1, next == internet
```

- [ ] **Step 3: Rodar e ver falhar** — `-only-testing:FinancasTests/ExpenseScheduleTests`.

- [ ] **Step 4: Implementar `ExpenseSchedule` e os tipos**

- [ ] **Step 5: Rodar `ExpenseScheduleTests`** — passa.

- [ ] **Step 6: Commit** — `feat(despesas): calcula ocorrências, estimado pela média e resumo do mês`

---

### Task 3: Rascunhos do cadastro e da conta do mês

**Files:**
- Create: `Financas/Expenses/ExpenseDraft.swift`, `ExpenseBillDraft.swift`, `ExpenseSheetMode.swift`, `ExpenseFormat.swift`
- Test: `FinancasTests/ExpenseDraftTests.swift`, `FinancasTests/ExpenseBillDraftTests.swift`, `FinancasTests/ExpenseFormatTests.swift`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `struct ExpenseDraft: Equatable { var name: String; var estimatedAmount: Decimal?; var dayOfMonth: Int; var startMonth: YearMonth; var endMonth: YearMonth?; let expenseID: UUID; let isNew: Bool; init(today: CalendarDay); init(expense: Expense, snapshot: ExpenseSnapshot, today: CalendarDay); var validationMessage: String?; func build(today: CalendarDay) -> (Expense, ExpenseTerm?) }`.
  - `enum ExpenseSheetMode: Hashable { case bill, payment }`.
  - `struct ExpenseBillDraft: Equatable { var mode: ExpenseSheetMode; var billAmount: Decimal; var billDueDate: CalendarDay; var paidAmount: Decimal; var paidOn: CalendarDay; init(occurrence: ExpenseOccurrence, today: CalendarDay, mode: ExpenseSheetMode? = nil); func billSaved(for: ExpenseOccurrence) -> ExpenseBill; func paymentSaved(for: ExpenseOccurrence) -> ExpenseBill; func billRemoved(for: ExpenseOccurrence) -> ExpenseBill?; func paymentRemoved(for: ExpenseOccurrence) -> ExpenseBill? }` — os `*Removed` devolvem `nil` quando a linha fica vazia (`isEmpty`), sinal para apagar.
  - `enum ExpenseFormat { static func origin(_ o: ExpenseOccurrence) -> String; static func rule(_ term: ExpenseTerm, estimate: ExpenseEstimate) -> String; static func occurrenceTitle(_ o: ExpenseOccurrence, today: CalendarDay) -> String }`.

Regras:
- `build` novo: term com `validFrom = startMonth`, `averageFrom = startMonth`.
- `build` edição: se estimado ou dia mudou, `validFrom = max(today.yearMonth, startMonth)`; reaproveita o `id` do term existente com o mesmo `validFrom`. `averageFrom`: se o estimado mudou, `validFrom > today.yearMonth ? validFrom : validFrom.next`; se só o dia mudou, o `averageFrom` do term vigente. Nada mudou: term `nil`.
- `validationMessage`: "Dê um nome para a despesa.", "Informe um valor maior que zero.", "O mês de fim precisa ser depois do início."
- `ExpenseBillDraft` padrão: `mode` = parâmetro, senão `.payment` se `hasBill` ou já paga, senão `.bill`; `billAmount` = `bill?.billAmount ?? occurrence.amount`; `billDueDate` = `occurrence.dueDate`; `paidAmount` = `bill?.paidAmount ?? bill?.billAmount ?? occurrence.estimate.amount`; `paidOn` = `bill?.paidOn ?? today`.
- `origin`: `.average` → "estimado pela média de jul, ago e set" (meses abreviados, minúsculos, `IncomeFormat.locale`); `.manual` → "estimado"; com conta → "conta lançada"; paga → "paga em \(shortDate)".
- `rule`: "Todo dia 13 · média de 3 meses" ou "Todo dia 26 · estimado".
- `occurrenceTitle`: nome; com " · \(monthName)" quando `month < today.yearMonth`.

- [ ] **Step 1: Testes que falham**

```swift
// ExpenseDraftTests
@Test func newDraftBuildsTermFromStartMonth()
@Test func editingEstimateStartsAverageNextMonth() // hoje out, start jul → validFrom out, averageFrom nov
@Test func editingOnlyDayKeepsAverageFrom()
@Test func editingFutureExpenseReplacesInitialTerm() // start dez → validFrom dez, mesmo id do term inicial, averageFrom dez
@Test func secondEditSameMonthReusesTerm() // estimado em out, depois só o dia → mesmo id, averageFrom continua nov
@Test func unchangedEditReturnsNoTerm()
@Test func validationMessages()
// ExpenseBillDraftTests
@Test func opensInBillModeWithoutBill() / opensInPaymentModeWithBill() / explicitModeWins()
@Test func paymentDefaultsToBillAmount() / paymentDefaultsToEstimateWithoutBill()
@Test func removingPaymentKeepsBill() / removingLastRecordReturnsNil()
// ExpenseFormatTests
@Test func originTexts() / ruleTexts() / titleShowsMonthOnlyForPreviousMonths()
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar as três suítes** — passam.
- [ ] **Step 5: Commit** — `feat(despesas): adiciona rascunhos do cadastro e da conta do mês`

---

### Task 4: `ExpenseStore`

**Files:**
- Create: `Financas/Expenses/ExpenseStore.swift`
- Modify: `FinancasTests/Fakes.swift` (adiciona `FakeExpenseService`, mesmo formato do `FakeIncomeService`, com `calls`, `nextError`, `holdsResponses`)
- Test: `FinancasTests/ExpenseStoreTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3, `IncomeLoadState`, `IncomeError`, `DueItem`.
- Produces: `@MainActor @Observable final class ExpenseStore` com
  - `private(set) var snapshot: ExpenseSnapshot`, `loadState: IncomeLoadState`, `isSaving: Bool`, `errorMessage: String?`;
  - `init(service: ExpenseService)`; `load() async`; `@discardableResult refresh() async -> Bool`; `reset()`;
  - `occurrences(in: YearMonth, today: CalendarDay) -> [ExpenseOccurrence]` (mês atual inclui `carried`);
  - `overdueOccurrences(today:) -> [ExpenseOccurrence]` (vencimento, depois nome com `localizedStandardCompare`), `overdueTotal(today:) -> Decimal`;
  - `summary(for: YearMonth, today: CalendarDay) -> ExpenseMonthSummary`;
  - `dueItems(today:) -> [DueItem]?` (nil se não carregado; mês anterior, atual e seguinte, sem pagas, sem repetição);
  - `currentTerm(for: Expense, today:) -> ExpenseTerm?`, `currentEstimate(for: Expense, today:) -> ExpenseEstimate?` (para a linha "Cadastradas" com `ExpenseFormat.rule`), `activeExpenses(today:)`, `endedExpenses(today:)` (ordem por nome);
  - `save(_ draft: ExpenseDraft, today:) async -> Bool`, `end(_ expense:, in month:) async -> Bool`, `delete(_ expense:) async -> Bool`;
  - `saveBill(_ draft: ExpenseBillDraft, for: ExpenseOccurrence) async -> Bool`, `removeBill(_ draft:, for:)`, `markPaid(_ draft:, for:)`, `unmarkPaid(_ draft:, for:)` — usam os `*Saved`/`*Removed` da Task 3; `nil` vira `deleteBill`.
- Mesmo padrão do `IncomeStore`: `perform` com `generation`, mensagem de erro em `errorMessage`, falha de carga em `loadState = .failed` com `.network → message`, `.unknown → ExpenseConstants.loadFailedMessage`.
- `DueItem` ganha o init de despesa na Task 7; aqui `dueItems` já usa `DueItem(expense:)` — criar `Financas/Reminders/DueItem+Expense.swift` e o caso `DueItemKind.expense` nesta task, com `title: ExpenseFormat.occurrenceTitle(o, today:)` e `amount: o.amount`.

- [ ] **Step 1: Testes que falham**

```swift
@Test func loadFailureShowsExpenseMessage()
@Test func markPaidWithoutBillCreatesRow() // calls == ["saveBill"], snapshot.bills.count == 1
@Test func unmarkPaidKeepsBill() // bill + pagamento → unmark → "saveBill", billAmount mantido, paidOn nil
@Test func removeBillOfPaidMonthKeepsPayment()
@Test func unmarkLastRecordDeletesRow() // → "deleteBill", bills vazio
@Test func networkErrorKeepsStateAndShowsMessage()
@Test func saveEditReusesTermForSameMonth()
@Test func dueItemsSkipPaidAndIncludePreviousMonthOverdue()
@Test func resetClearsEverything()
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `ExpenseStoreTests` e a suíte inteira** — passam.
- [ ] **Step 5: Commit** — `feat(despesas): adiciona store de despesas`

---

### Task 5: Linhas sem ícones

**Files:**
- Modify: `Financas/Income/OccurrenceRow.swift`, `RecurringIncomeRow.swift`, `Financas/Reminders/OverdueRow.swift`, `Financas/Home/TransactionRow.swift`, `Financas/Income/IncomesView.swift`, `EndedIncomesView.swift`, `Financas/Reminders/OverdueView.swift`, `Financas/Home/HomeView.swift`
- Delete: `Financas/Income/IncomeIcon.swift`; em `IncomeKindStyle.swift`, remover `systemImage`/`tint` se ficarem sem uso.

- [ ] **Step 1: Tirar `IncomeIcon` das quatro linhas** e trocar `Divider().padding(.leading, 48)` por `Divider()` nas listas.
- [ ] **Step 2: `xcodegen generate` e build** — `xcodebuild build -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -quiet` sem erros e sem warnings novos; suíte inteira passa.
- [ ] **Step 3: Commit** — `style: remove os ícones das linhas de receitas`

---

### Task 6: Aba Despesas

**Files:**
- Create: `Financas/Expenses/ExpensesView.swift`, `ExpenseFormView.swift`, `ExpenseSheet.swift`, `ExpenseFlow.swift`, `ExpenseOccurrenceRow.swift`, `ExpenseRow.swift`, `EndedExpensesView.swift`, `ExpenseLoadContent.swift`, `ExpenseMonthSummaryCard.swift`
- Modify: `Financas/Home/AppTab.swift` (`case expenses`, entre `incomes` e `overdue`), `Financas/Home/MainTabView.swift`, `Financas/FinancasApp.swift`, `Financas/RootView.swift`

**Interfaces:**
- Consumes: `ExpenseStore` (Task 4), `ExpenseBillDraft`/`ExpenseDraft`/`ExpenseFormat` (Task 3), `IncomeStore.selectedMonth`/`today`.
- Produces: `ExpenseFlow` (`.expenseFlow(paying: Binding<ExpenseSheetTarget?>, editing: Binding<ExpenseDraft?>)`) com `struct ExpenseSheetTarget: Identifiable { let occurrence: ExpenseOccurrence; let mode: ExpenseSheetMode? }`, usado também pela aba Atrasadas.

Comportamento (spec, "Aba Despesas" e "Lançar conta e marcar como paga"):
- `ExpensesView` espelha `IncomesView`: `MonthPicker` em `$incomeStore.selectedMonth`, `ExpenseMonthSummaryCard` (Pago em `Theme.positive`, Falta pagar, Previsto), seções "A pagar", "Pagas", "Cadastradas" + "Encerradas", estado vazio "Nenhuma despesa cadastrada" / "Cadastre suas contas fixas para ver quanto falta pagar no mês." / botão "Cadastrar despesa", toolbar "Nova despesa" (`plus`), `refreshable`.
- `ExpenseOccurrenceRow`: título, legenda (vencimento, ou "pago em …"), valor ("− " quando paga) e selo: "atrasada" (`OverdueBadge`), "conta lançada", "estimada".
- `ExpenseSheet`: título "\(nome) · \(mês)", "Vence \(shortDate)", valor em destaque e `ExpenseFormat.origin`; `Picker` segmentado "Lançar conta" / "Marcar como paga"; campos do modo; botões "Salvar conta" / "Marcar como paga"; quando há registro, ações "Remover conta" / "Desmarcar pagamento"; "Editar despesa" leva ao formulário como no `ReceiptSheet`. `DatePicker` do pagamento só até hoje.
- `ExpenseFormView` espelha `IncomeFormView` sem tipo: nome, valor estimado, dia de vencimento, mês de início, mês de fim; edição com "Encerrar" e "Excluir" com confirmação na tela.
- Aba no `MainTabView`: `Label("Despesas", systemImage: "arrow.up.circle").labelStyle(.iconOnly)`.
- `FinancasApp`: cria `ExpenseStore(service: SupabaseExpenseService(client:))`, injeta no environment, chama `expenses.reset()` no `onSignedOut`.
- `RootView`: no desbloqueio e no `NSCalendarDayChanged`, `refresh()` dos dois stores; `onChange(of: expenseStore.snapshot)` chama `syncReminders()`.

- [ ] **Step 1: Implementar as views e a ligação no app.**
- [ ] **Step 2: `xcodegen generate`, build e suíte inteira** — sem erros.
- [ ] **Step 3: Conferir no simulador** (aplicando a migration num projeto de teste só com aprovação; sem ela, conferir estados de carregando/erro): cadastrar luz e internet, lançar a conta da luz, pagar a internet, remover a conta, desmarcar, editar, encerrar e excluir.
- [ ] **Step 4: Commit** — `feat(despesas): adiciona a aba de despesas`

---

### Task 7: Avisos com despesas

**Files:**
- Modify: `Financas/Reminders/ReminderPlanner.swift`, `ReminderText.swift`, `ReminderRoute.swift` (`case expenses`), `ReminderScheduler.swift`, `BackgroundReminderRefresh.swift`, `Financas/FinancasApp.swift`, `Financas/RootView.swift`, `Financas/Home/MainTabView.swift`
- Test: `FinancasTests/ReminderPlannerTests.swift`, `ReminderSchedulerTests.swift`, `BackgroundReminderRefreshTests.swift`

**Interfaces:**
- Consumes: `DueItemKind.expense` e `ExpenseStore.dueItems(today:)` (Task 4).
- Produces:
  - `ReminderScheduler.requestPermissionIfNeeded(hasEntries: Bool)` (renomeia `hasIncomes`).
  - `BackgroundReminderRefresh.run(hasSession:incomes:expenses:reschedule:)` — refresh dos dois; só reagenda se os dois deram certo.

Regras do planner, por dia da janela:
- Atraso: itens com `dueDate < day`, dos dois tipos; um aviso por horário de atraso ligado; `route: .overdue`; id `overdue-…` como hoje.
- Hoje, manhã (`dueTodayEnabled`, `dueTodayTime`): itens com `dueDate == day`, dos dois tipos; id `due-…`; `route` = `.expenses` se houver despesa, senão `.incomes`.
- Hoje, noite (`overdueEveningEnabled`, `overdueEveningTime`): só despesas com `dueDate == day`; id `duelate-…`; `route: .expenses`. Não sai se `overdueEveningTime == dueTodayTime` com os dois ligados.
- Textos: tabela "Avisos" do spec, exatamente. Plural: "1 receita", "2 receitas", "1 conta", "2 contas". Só receitas: textos atuais.
- `MainTabView.applyPendingRoute`: `.expenses` → `incomeStore.showCurrentMonth()` e aba `.expenses`.
- `RootView.syncReminders()`: itens = `incomeStore.dueItems` + `expenseStore.dueItems(today: incomeStore.today)`; só segue se os dois não forem `nil`; permissão com `hasEntries: !incomes.isEmpty || !expenses.isEmpty`.

- [ ] **Step 1: Testes que falham**

```swift
@Test func expenseDueTodayFiresMorningAndEvening() // luz vence 19/10 → due-2026-10-19-0800 e duelate-2026-10-19-1900, títulos "Conta vence hoje"
@Test func eveningDueRespectsToggle() // overdueEveningEnabled false → só o da manhã
@Test func eveningDueSkippedWhenSameTimeAsMorning()
@Test func incomeAndExpenseShareOneReminder() // título "Hoje: 1 receita e 2 contas", corpo "R$ 13.020,04 a receber e R$ 306,40 a pagar."
@Test func mixedOverdueText() // "Atrasadas: 1 receita e 2 contas"
@Test func expenseOverdueTexts() // "Conta atrasada" / "Luz · R$ 212,30, venceu em ter, 13 out." e "2 contas atrasadas" / "R$ 306,40 ainda não pagos."
@Test func paidExpenseHasNoReminder()
@Test func routes() // due com despesa → .expenses; só receita → .incomes; atraso → .overdue
@Test func atMost56RemindersIn14Days()
@Test func permissionAskedWithOnlyExpenses() // ReminderSchedulerTests
@Test func backgroundSkipsWhenExpenseRefreshFails() // BackgroundReminderRefreshTests
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar as suítes de avisos e a inteira** — passam.
- [ ] **Step 5: Commit** — `feat(avisos): avisa vencimento e atraso de despesas`

---

### Task 8: Aba Atrasadas com despesas

**Files:**
- Modify: `Financas/Reminders/OverdueView.swift`, `OverdueTotalCard.swift`, `Financas/Home/MainTabView.swift` (badge)
- Create: `Financas/Reminders/OverdueExpenseRow.swift`

- [ ] **Step 1: Implementar**
  - `OverdueTotalCard(incoming: Decimal, outgoing: Decimal)`: linhas "A receber" e "A pagar" em `Theme.warning`, cada uma só quando maior que zero.
  - Seção "Despesas" abaixo de "Receitas" com `expenseStore.overdueOccurrences(today:)`; legenda "\(vencimento) · \(n) dias", mês ao lado do valor quando de mês anterior (como `OverdueRow`). Tocar abre `ExpenseFlow` com `mode: .payment`.
  - Seção vazia não aparece; "Nada atrasado" só com as duas vazias; texto do estado vazio passa a falar de receitas e contas.
  - Seção de despesas só aparece com `expenseStore.loadState == .loaded`. `refreshable` recarrega os dois stores.
  - Badge: soma das duas contagens.
- [ ] **Step 2: Build e suíte inteira** — sem erros.
- [ ] **Step 3: Conferir no simulador** — despesa atrasada aparece, badge soma, pagar tira da lista.
- [ ] **Step 4: Commit** — `feat(atrasadas): mostra despesas atrasadas`

---

### Task 9: Home com despesas

**Files:**
- Modify: `Financas/Home/HomeMonthSummary.swift`, `HomeEntry.swift`, `TransactionRow.swift`, `HomeView.swift`
- Create: `Financas/Home/HomeEntryKind.swift`, `Financas/Home/MonthBalanceCard.swift` (substitui o uso de `IncomeSummaryCard`; apagar `IncomeSummaryCard.swift`)
- Test: `FinancasTests/HomeMonthSummaryTests.swift`

**Interfaces:**
- Produces:
  - `enum HomeEntryKind: Equatable { case income, expense }`; `HomeEntry` troca `kind: IncomeKind` por `kind: HomeEntryKind` e `receivedOn` por `date: CalendarDay`.
  - `HomeMonthSummary.make(month:snapshot:expenses: ExpenseSnapshot, today:)`.
  - `MonthBalanceCard(openIncomes: () -> Void, openExpenses: () -> Void)`.

- [ ] **Step 1: Testes que falham**

```swift
@Test func balanceSubtractsPaymentsInMonth() // recebido 13.020,04 em 1/10, pago 1.150 em 9/10 → 11.870,04
@Test func paymentCountsInMonthOfPaymentDate() // conta de setembro paga em 2/10 → entra em outubro
@Test func chartGoesDownOnPaymentDay()
@Test func entriesMixAndSortByDate() // pagamento "Condomínio", kind .expense, antes da receita do dia 1
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar**
  - `HomeMonthSummary`: pagamentos por `paidOn` no mês; título da despesa é o nome.
  - `TransactionRow`: despesa com legenda "Despesa · \(dia)" e valor "− \(valor)" na cor primária; receita como hoje.
  - `MonthBalanceCard`: duas metades iguais em largura, separadas por divisória vertical. Cada metade: rótulo ("Falta receber" / "Falta pagar"), valor, `ProgressView` (já entrou / já pago sobre previsto), próxima ("Água · 19 out"), selo de atrasadas com o número. Metade sem cadastro: "Cadastre suas receitas" / "Cadastre suas contas fixas". Carregando e erro por metade, com "Tentar de novo". Tocar abre a aba no mês da home.
- [ ] **Step 4: Rodar `HomeMonthSummaryTests` e a suíte inteira** — passam.
- [ ] **Step 5: Conferir no simulador** a home em iPhone e na largura do iPad.
- [ ] **Step 6: Commit** — `feat(home): mostra falta pagar e inclui pagamentos no saldo`

---

### Task 10: Migration no Supabase e validação manual

- [ ] **Step 1: Pedir aprovação do dono** para aplicar `20261017040000_create_expenses.sql` no projeto Supabase.
- [ ] **Step 2: Aplicar e conferir** — advisors de segurança sem aviso novo; SQL com outro `sub` não lê nem altera `expenses`, `expense_terms`, `expense_bills`; insert de bill vazio e de bill com `bill_amount` sem `bill_due_date` é rejeitado.
- [ ] **Step 3: Validação manual do spec** — no iPhone: cadastrar luz e internet, lançar a conta da luz, pagar a internet, conferir aba, home e Atrasadas; adiantar o relógio para o dia do vencimento e ver os avisos de manhã e de noite; pagar e ver os avisos sumirem; abrir no iPad e ver os mesmos dados.
