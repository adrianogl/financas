# Partes e gasto do mês Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contas com vencimento podem ter partes com valor e histórico próprios. Um novo tipo de despesa, "gasto do mês", tem previsto mensal e lançamentos rápidos.

**Architecture:** O modelo de hoje continua: o banco guarda cadastro, vigências e registros, e o app calcula as ocorrências. As partes ganham duas tabelas: `expense_parts` e `expense_part_terms`. A vigência da parte tem `is_active`, e é ela que liga, encerra e reativa a parte. O valor de cada parte na conta e no pagamento fica em colunas `jsonb` de `expense_bills`, e assim a conta e as partes são salvas num único upsert. O gasto do mês reaproveita `expense_terms` para o previsto e ganha a tabela `expense_entries`. O cálculo novo fica em tipos puros ao lado de `ExpenseSchedule`.

**Tech Stack:** SwiftUI (iOS 26), Swift 6, Swift Testing, Supabase (supabase-swift 2.55.4), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-18-partes-e-gasto-do-mes-design.md` (mockup em `docs/superpowers/mockups/2026-10-18-partes-e-gasto-do-mes.html`).

## Global Constraints

- Sem comentários no código.
- Types e constantes em arquivo próprio: um tipo por arquivo e constantes em `ExpenseConstants.swift` (ou num `*Constants.swift` da pasta).
- Textos em PT-BR, exatamente como na spec quando ela fixa o texto.
- Uma despesa sem partes, do tipo conta com vencimento, se comporta exatamente como hoje. Todos os testes que já existem continuam passando sem mudar as asserções. Só as chamadas que quebrarem por assinatura nova podem mudar.
- Depois de criar arquivos, rodar `xcodegen generate`.
- Testes: `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination "id=30493143-5FCC-4EE1-9047-DCD0FA3E8597"` (simulador iPhone Air). Se o ID não existir, usar `xcrun simctl list devices available` e escolher um iPhone.
- Commits locais por tarefa, em Conventional Commits em PT-BR, sem trailer de co-autoria e sem citar IA. Sem push.
- A migration não é aplicada no Supabase por nenhum agente. O dono aplica depois da revisão final.

## Review Focus

1. Conta com partes paga no mês atual, quando o dono edita as partes: o mês atual não pode mudar de valor, e a mudança vale do mês seguinte (teste em Task 4).
2. Pagamento de conta com partes: o `paidAmount` gravado é sempre igual à soma de `paidParts` (teste em Task 5).
3. Gasto do mês nunca aparece em `occurrences`, `overdueOccurrences`, `dueItems` e Atrasadas (teste em Task 3).
4. Lançamento com data em outro mês conta no mês da sua data, não no mês que estava na tela (teste em Task 3).
5. Remover a última parte deixa a despesa com valor único igual à soma dos valores vigentes das partes, como Varia, e com a média reiniciada (teste em Task 4).

---

### Task 1: Banco, modelos, serviço e snapshot

**Files:**
- Create: `supabase/migrations/20261018010000_add_expense_parts_and_entries.sql`
- Create: `Financas/Expenses/ExpenseKind.swift`, `ExpensePart.swift`, `ExpensePartTerm.swift`, `ExpenseEntry.swift`
- Modify: `Financas/Expenses/Expense.swift`, `ExpenseBill.swift`, `ExpenseSnapshot.swift`, `ExpenseService.swift`, `SupabaseExpenseService.swift`, `ExpenseConstants.swift`, `ExpenseStore.swift` (só `delete` e o que quebrar)
- Modify: `FinancasTests/Fakes.swift` (`FakeExpenseService`)
- Test: `FinancasTests/ExpenseCodingTests.swift`, `FinancasTests/ExpenseStoreTests.swift`

**Interfaces:**
- Produces:
  - `enum ExpenseKind: String, Codable, Sendable { case bill, spending }`
  - `Expense.kind: ExpenseKind = .bill`, coluna `kind`
  - `struct ExpensePart: Identifiable, Hashable, Codable, Sendable { let id: UUID; let expenseID: UUID; var name: String; var position: Int }`, colunas `id, expense_id, name, position`
  - `struct ExpensePartTerm: Identifiable, Hashable, Codable, Sendable { let id: UUID; let partID: UUID; var validFrom: YearMonth; var amount: Decimal; var isFixed: Bool; var averageFrom: YearMonth; var isActive: Bool }`, colunas `id, part_id, valid_from, amount, is_fixed, average_from, is_active`
  - `struct ExpenseEntry: Identifiable, Hashable, Codable, Sendable { let id: UUID; let expenseID: UUID; var spentOn: CalendarDay; var amount: Decimal }`, colunas `id, expense_id, spent_on, amount`
  - `ExpenseBill.billParts: [UUID: Decimal]?` e `ExpenseBill.paidParts: [UUID: Decimal]?`, colunas `bill_parts` e `paid_parts` (`jsonb`), codificadas como objeto JSON com o `uuidString` minúsculo como chave. Nil vira `null`.
  - `ExpenseSnapshot` ganha `var parts: [ExpensePart] = []`, `var partTerms: [ExpensePartTerm] = []` e `var entries: [ExpenseEntry] = []`. O init com 3 argumentos continua compilando.
  - `ExpenseService`:
    - troca `save(_:term:)` por `save(_ expense: Expense, term: ExpenseTerm?, parts: [ExpensePart], partTerms: [ExpensePartTerm]) async throws(IncomeError)`;
    - novos `save(_ entry: ExpenseEntry)` e `deleteEntry(id: UUID)`.
  - `FakeExpenseService` registra as chamadas `saveExpense`, `saveEntry` e `deleteEntry`, e guarda a última chamada de save em `lastSavedParts` e `lastSavedPartTerms`.
  - Constantes `partsTable = "expense_parts"`, `partTermsTable = "expense_part_terms"`, `entriesTable = "expense_entries"`.

- [ ] **Step 1: Escrever a migration**

  Tudo com RLS no padrão de `20261017040000_create_expenses.sql`: políticas select, insert, update e delete com `(select auth.uid()) = user_id`, e insert e update checando o dono do pai.
  - `expenses.kind text not null default 'bill' check (kind in ('bill','spending'))`.
  - Tabela `expense_parts`:
    - colunas `id`, `user_id`, `expense_id` (cascade), `name text not null check (length(trim(name)) > 0)` e `position smallint not null`;
    - `unique (expense_id, name)`.
  - Tabela `expense_part_terms`:
    - colunas `id`, `user_id`, `part_id` (cascade), `valid_from date` (dia 1), `amount numeric(12,2) not null check (amount > 0)`, `is_fixed boolean not null`, `average_from date` (dia 1) e `is_active boolean not null`;
    - `unique (part_id, valid_from)`.
  - Tabela `expense_entries`:
    - colunas `id`, `user_id`, `expense_id` (cascade), `spent_on date not null` e `amount numeric(12,2) not null check (amount > 0)`;
    - índice em `user_id`.
  - `expense_bills` ganha `bill_parts jsonb` e `paid_parts jsonb`.
  - Índices em `user_id` nas tabelas novas.

- [ ] **Step 2: Testes de codificação (falham)**

  Em `ExpenseCodingTests`:
  - `decodesExpenseWithKind`: o JSON com `"kind":"spending","is_fixed":false` decodifica `.spending`.
  - `encodesBillParts`: um bill com `billParts = [id: 110]` codifica `bill_parts` como `[id.uuidString.lowercased(): 110]` e `paid_parts` como `NSNull`.
  - `decodesBillParts`: o JSON com `"bill_parts":{"<uuid>":110.5},"paid_parts":null` decodifica `[uuid: 110.5]` e `nil`.
  - `decodesPartTermAndEntry`: o JSON de `ExpensePartTerm` e o de `ExpenseEntry`, com `spent_on` `"2026-10-17"`, decodificam com os valores certos.

- [ ] **Step 3: Implementar modelos, snapshot, serviço e fake**

  - `SupabaseExpenseService.load` carrega as seis tabelas em paralelo.
  - `save(_:term:parts:partTerms:)` faz upsert da despesa, depois do term (como hoje), depois de `parts` (`onConflict: "id"`) e depois de `partTerms` (`onConflict: "part_id,valid_from"`). Upsert de array vazio não é enviado.
  - `ExpenseStore.save` passa `parts: []` e `partTerms: []` até a Task 4.
  - `ExpenseStore.delete` também remove do snapshot as `parts` da despesa, os `partTerms` dessas partes e as `entries` dela.

- [ ] **Step 4: Teste do store (falha antes, passa depois)**

  `deleteRemovesPartsTermsAndEntries`: com um snapshot que tem uma parte, um term de parte e um entry da luz, `store.delete(S.luz)` deixa os três vazios.

- [ ] **Step 5: `xcodegen generate`, rodar a suíte completa, commit**

  `feat(despesas): adiciona tabelas e modelos de partes e gasto do mês`

---

### Task 2: Cálculo das partes

**Files:**
- Create: `Financas/Expenses/ExpensePartSchedule.swift`, `ExpensePartValue.swift`, `ExpensePartOrigin.swift`
- Modify: `Financas/Expenses/ExpenseSchedule.swift`, `ExpenseEstimate.swift`, `ExpenseFormat.swift`, `ExpenseOccurrence.swift`
- Modify: `FinancasTests/ExpenseSamples.swift` (helpers `part`, `partTerm`)
- Test: `FinancasTests/ExpensePartScheduleTests.swift`, `FinancasTests/ExpenseFormatTests.swift`

**Interfaces:**
- Consumes: modelos da Task 1.
- Produces:
  - `enum ExpensePartOrigin: Hashable { case paid, bill, fixed, average(months: [YearMonth]), estimated }`
  - `struct ExpensePartValue: Hashable, Identifiable { let part: ExpensePart; let amount: Decimal; let origin: ExpensePartOrigin; let isFixed: Bool; var id: UUID { part.id } }`
  - `enum ExpensePartSchedule` com:
    - `static func term(for part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpensePartTerm?`: a vigência com o maior `validFrom <= month`; nil se não houver.
    - `static func activeParts(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> [ExpensePart]`: as partes com `term?.isActive == true`, ordenadas por `position`.
    - `static func estimate(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpensePartValue?`: regras 3 a 5 da spec. A média usa os valores de `paidParts[part.id]` dos bills com `month < M` e `month >= term.averageFrom`, os 3 mais recentes, com o arredondamento de `ExpenseSchedule.estimate`.
    - `static func values(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> [ExpensePartValue]`: regras 1 a 5. Primeiro `paidParts[id]` do bill do mês (`.paid`), depois `billParts[id]` (`.bill`), senão `estimate`. Vazio quando não há parte ativa.
    - `static func change(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal?`: o valor registrado (paid ou bill) em M menos o registrado em `M.previous`; nil se faltar algum dos dois.
  - `ExpenseEstimate` ganha `case parts(Decimal)`. `ExpenseSchedule.estimate(for:in:snapshot:)` retorna `.parts(soma dos estimate das partes ativas)` quando a despesa tem parte ativa no mês e ignora `isFixed`.
  - `ExpenseOccurrence.parts: [ExpensePartValue]`, preenchido por `ExpenseSchedule.occurrence`.
  - `ExpenseSchedule.occurrences`, `earlier` e `carried` ignoram despesas com `kind == .spending`.
  - `ExpenseFormat`:
    - `origin` com `.parts` retorna `"soma das partes"`;
    - `rule` com `.parts` retorna `"Todo dia \(dia) · \(n) partes"` (1 parte: `"1 parte"`);
    - `partNames(_ values: [ExpensePartValue]) -> String` junta os nomes em minúsculas com o mesmo `list` de hoje (`"taxa, água e gás"`);
    - `partCaption(_ value: ExpensePartValue, change: Decimal?, previous: YearMonth) -> String` retorna `"fixo"` para parte fixa, `"▲ R$ 30,00 vs. setembro"` ou `"▼ R$ 5,00 vs. setembro"` com `change`, e `"varia"` sem ele.

- [ ] **Step 1: Testes que falham**

  Em `ExpensePartScheduleTests` use o condomínio com 3 partes: Taxa (fixo, 820), Água (varia, 85) e Gás (varia, 80), todas a partir de 2026-07.
  - `fixedPartUsesRegisteredAmount`: Taxa em outubro vale 820 `.fixed`, mesmo com 3 meses pagos de 900.
  - `variablePartAveragesLastThreePaid`: Água paga 70, 80 e 90 em jul, ago e set vale 80 `.average` em outubro.
  - `variablePartWithTwoPaidUsesRegistered`: vale 85 `.estimated`.
  - `paidAndBillOverrideEstimate`: o bill de outubro com `billParts[agua] = 110` dá `.bill` 110. Com `paidParts[agua] = 112`, dá `.paid` 112.
  - `occurrenceAmountIsSumOfParts`: sem registro, a ocorrência de outubro vale 820 + 85 + 80 = 985, com estimate `.parts(985)`.
  - `inactivePartLeavesFromItsMonth`: um term de Gás com `validFrom` 2026-11 e `isActive` false tira o Gás de novembro e o mantém em outubro.
  - `reactivatedPartKeepsAverageHistory`: Gás inativo em nov e ativo de novo em dez, com `averageFrom` jul, ainda faz média com os pagamentos de jul a set.
  - `changeComparesRegisteredMonths`: Água com 80 pago em setembro e 110 lançado em outubro dá `change` 30. Sem registro em setembro, dá nil.
  - `spendingIsNotAnOccurrence`: uma despesa `.spending` com term não aparece em `occurrences`, `carried`, `overdue` nem `summary.overdueCount`.
  - Em `ExpenseFormatTests`, `partTexts` cobre `rule`, `origin`, `partNames` e `partCaption` com os textos exatos acima.

- [ ] **Step 2: Implementar e rodar a suíte completa, commit**

  `feat(despesas): calcula o valor de cada parte da conta`

---

### Task 3: Cálculo do gasto do mês e resumos

**Files:**
- Create: `Financas/Expenses/SpendingMonth.swift`, `SpendingSchedule.swift`
- Modify: `Financas/Expenses/ExpenseSchedule.swift` (`summary`), `Financas/Home/HomeMonthSummary.swift`, `Financas/Expenses/ExpenseStore.swift`
- Test: `FinancasTests/SpendingScheduleTests.swift`, `FinancasTests/HomeMonthSummaryTests.swift`, `FinancasTests/ExpenseStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 e o filtro `.spending` da Task 2.
- Produces:
  - `struct SpendingMonth: Identifiable, Hashable { let expense: Expense; let month: YearMonth; let expected: Decimal; let spent: Decimal; let remaining: Decimal; let entries: [ExpenseEntry]; var isOver: Bool { spent > expected }; var excess: Decimal { max(spent - expected, 0) }; var id: String }`. O `id` é `"\(expense.id)-\(month.year)-\(month.month)"`, e `entries` vem ordenado por `spentOn` decrescente.
  - `enum SpendingSchedule` com:
    - `static func month(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> SpendingMonth?`: nil fora do período da despesa ou sem term. `expected` é o `estimatedAmount` do term vigente. `remaining` é `max(expected - spent, 0)` quando `month >= today.yearMonth`, senão 0.
    - `static func months(in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [SpendingMonth]`: ordena por nome com `localizedStandardCompare`.
    - `static func history(of expense: Expense, through month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [SpendingMonth]`: até `SpendingConstants.historyMonths = 6` meses, de `month` para trás, parando no início da despesa e em ordem cronológica. A constante fica em `ExpenseConstants`, como `spendingHistoryMonths`.
  - `ExpenseSchedule.summary`: `paid` soma o `spent`, e `remaining` soma o `remaining` dos gastos do mês. `overdueCount` e `next` não mudam.
  - `HomeMonthSummary.make`: cada entry com `spentOn.yearMonth == month` de despesa existente vira um movimento negativo no dia dele e uma `HomeEntry(id: entry.id, title: nome, kind: .expense, date: spentOn, amount:)`.
  - `ExpenseStore.spendings(in month: YearMonth, today: CalendarDay) -> [SpendingMonth]` e `ExpenseStore.spendingHistory(of: Expense, through: YearMonth, today: CalendarDay) -> [SpendingMonth]`.

- [ ] **Step 1: Testes que falham**

  Use o abastecimento: `.spending`, previsto 600 a partir de 2026-10, com entries de 130 (02/10), 140 (10/10) e 150 (17/10). Hoje é 17/10.
  - `spentAndRemainingInCurrentMonth`: spent 420, remaining 180, entries em ordem 17, 10, 2.
  - `pastMonthHasNoRemaining`: em setembro, com previsto a partir de 2026-09 e uma entry de 100, remaining é 0.
  - `overExpected`: entries que somam 650 dão `isOver` true, `excess` 50 e remaining 0.
  - `entryCountsInMonthOfItsDate`: uma entry de 31/10 conta em outubro e não em novembro. Uma de 01/11 conta em novembro.
  - `historyStopsAtStartAndKeepsSix`: com início em 2026-01 e o mês 2026-10, vêm 6 meses, de mai a out. Com início em 2026-09, vêm 2.
  - `summaryIncludesSpending`: com só o abastecimento, outubro dá `paid` 420, `remaining` 180, `expected` 600, `overdueCount` 0 e `next` nil.
  - Em `HomeMonthSummaryTests`, `spendingEntriesAreExpenses`: as 3 entries entram em `entries` com `kind == .expense`, e o `balance` cai 420.
  - Em `ExpenseStoreTests`, `spendingNeverOverdueOrDue`: com uma entry no passado e nenhum gasto, `overdueOccurrences` e `dueItems` não trazem o abastecimento.

- [ ] **Step 2: Implementar e rodar a suíte completa, commit**

  `feat(despesas): calcula o gasto do mês nos resumos`

---

### Task 4: Cadastro com tipo e partes

**Files:**
- Create: `Financas/Expenses/ExpensePartDraft.swift`, `ExpensePartChanges.swift`
- Modify: `Financas/Expenses/ExpenseDraft.swift`, `ExpenseStore.swift` (`save`)
- Test: `FinancasTests/ExpenseDraftTests.swift`, `FinancasTests/ExpenseStoreTests.swift`

**Interfaces:**
- Consumes: Tasks 1 e 2 (`ExpensePartSchedule.term`, `activeParts`).
- Produces:
  - `struct ExpensePartDraft: Identifiable, Equatable { let id: UUID; var name: String; var isFixed: Bool; var amount: Decimal? }`. Para uma parte existente, `id` é o id da parte. Para uma nova, um UUID novo.
  - `struct ExpensePartChanges: Equatable { var parts: [ExpensePart]; var terms: [ExpensePartTerm] }`
  - `ExpenseDraft`:
    - novos campos `var kind: ExpenseKind` (novo: `.bill`; edição: o da despesa) e `var parts: [ExpensePartDraft]` (edição: as partes ativas no mês efetivo, com o term vigente);
    - `var effectiveMonth: YearMonth` (abaixo);
    - `mutating func addPart()` acrescenta `ExpensePartDraft(id: UUID(), name: "", isFixed: false, amount: nil)`;
    - `mutating func removePart(id: UUID)`: quando remove a última parte de uma despesa que tinha partes ao abrir, define `estimatedAmount` como a soma dos `amount` vigentes das partes que existiam ao abrir e `isFixed = false`;
    - `func buildParts(today: CalendarDay) -> ExpensePartChanges`.
  - `ExpenseStore.save` envia `buildParts` ao serviço e atualiza `snapshot.parts` e `snapshot.partTerms`, substituindo por `id` e por (`partID`, `validFrom`).

  Regras que o implementer não deduz sozinho:
  - **Mês efetivo**, para o term da despesa e para os terms das partes: `max(today.yearMonth, startMonth)`. Ele passa para `today.yearMonth.next` quando a despesa já existe e o bill de `today.yearMonth` tem `billAmount` ou `paidAmount`. O draft guarda essa informação no `init(expense:snapshot:today:)`.
  - `averageFrom` de um term novo de parte: se o valor mudou, ou se a parte é nova ou reativada, vale `effectiveMonth > today.yearMonth ? effectiveMonth : effectiveMonth.next`, a mesma regra do term da despesa. Despesa nova usa `startMonth`. Se só mudou `isFixed`, copia o `averageFrom` do term atual.
  - Casamento de partes: pelo `id`. Uma parte de draft com id desconhecido e nome igual (trim e sem diferença de maiúsculas) ao de uma parte encerrada da despesa reativa essa parte, mantendo o id antigo. `position` é o índice no draft.
  - Gera term no mês efetivo só para parte nova, reativada, com valor diferente ou com `isFixed` diferente. Parte ativa que sumiu do draft gera term com `isActive = false`, copiando valor e `isFixed`. Um term no mesmo `validFrom` reaproveita o id existente.
  - Renomear muda `ExpensePart.name` e entra em `parts`.
  - `validationMessage`:
    - parte com nome vazio: "Dê um nome para cada parte.";
    - nomes repetidos: "Cada parte precisa de um nome diferente.";
    - parte sem valor ou com valor ≤ 0: "Informe o valor de cada parte.";
    - com partes, o valor da despesa não é validado;
    - `.spending` valida o valor como hoje e ignora partes.
  - `.spending` grava o term com `dayOfMonth = 1`.
  - Com partes, `build(today:)` não gera um term novo da despesa por causa do valor. Só o dia gera.

- [ ] **Step 1: Testes que falham**

  - `newBillWithPartsBuildsTermsFromStart`: a despesa nova começa em 2026-11 com Taxa (fixo, 820) e Água (varia, 85). O resultado são 2 parts com position 0 e 1, e 2 terms com `validFrom` e `averageFrom` 2026-11 e `isActive` true.
  - `editingPartAmountStartsAverageNextMonth`: Água de 85 para 95 em 17/10 gera um term com `validFrom` 2026-10 e `averageFrom` 2026-11.
  - `changesWaitWhenCurrentMonthIsRegistered`: com o bill de outubro pago, mudar a Água gera um term com `validFrom` 2026-11.
  - `removingPartDeactivatesIt`: tirar o Gás gera um term do Gás com `isActive` false no mês efetivo.
  - `removingLastPartFallsBackToSum`: removendo Taxa, Água e Gás (820, 85, 80), o draft fica com `estimatedAmount` 985 e `isFixed` false. `build` gera um term da despesa com 985 e `averageFrom` 2026-11.
  - `readdingSameNameReactivatesPart`: com o Gás encerrado, adicionar "gás" gera um term com o id antigo do Gás e `isActive` true.
  - `partValidationMessages`: as três mensagens acima.
  - `spendingDraftIgnoresParts`: `kind = .spending`, valor 600, gera um term com `dayOfMonth` 1 e `buildParts` vazio.
  - No store, `saveSendsPartsAndUpdatesSnapshot`: o fake recebe as parts e os terms, e o snapshot passa a ter a parte nova.

- [ ] **Step 2: Implementar e rodar a suíte completa, commit**

  `feat(despesas): cadastra o tipo da despesa e as partes`

---

### Task 5: Conta e pagamento com partes, lançamentos do gasto do mês

**Files:**
- Create: `Financas/Expenses/ExpenseBillPartDraft.swift`, `ExpenseEntryDraft.swift`
- Modify: `Financas/Expenses/ExpenseBillDraft.swift`, `ExpenseStore.swift`
- Test: `FinancasTests/ExpenseBillDraftTests.swift`, `FinancasTests/ExpenseEntryDraftTests.swift`, `FinancasTests/ExpenseStoreTests.swift`

**Interfaces:**
- Consumes: `ExpenseOccurrence.parts` (Task 2), `ExpenseEntry` (Task 1).
- Produces:
  - `struct ExpenseBillPartDraft: Identifiable, Equatable { let id: UUID; let name: String; var amount: Decimal }`
  - `ExpenseBillDraft`:
    - ganha `var parts: [ExpenseBillPartDraft]`, montado com `occurrence.parts`. O valor inicial é `paidParts`, senão `billParts`, senão o valor da parte;
    - ganha `var partsTotal: Decimal`;
    - com partes, `billSaved` grava `billParts` e `billAmount = partsTotal`, e `paymentSaved` grava `paidParts` e `paidAmount = partsTotal`;
    - `billRemoved` limpa `billParts` e `paymentRemoved` limpa `paidParts`;
    - com partes, o modo padrão é `.payment` se todas as partes forem fixas. Senão, usa a regra de hoje sem olhar `expense.isFixed`.
  - `struct ExpenseEntryDraft: Equatable`:
    - campos `let expense: Expense`, `let entryID: UUID`, `let isNew: Bool`, `var amount: Decimal?` e `var spentOn: CalendarDay`;
    - `init(expense:month:today:)` usa `spentOn = today` quando `month == today.yearMonth` e o último dia de `month` quando `month < today.yearMonth`;
    - `init(entry:expense:)`;
    - `var validRange: ClosedRange<CalendarDay>` vai do primeiro dia de `expense.startMonth` até o menor entre hoje e o último dia de `endMonth`;
    - `validationMessage`: "Informe um valor maior que zero." ou "Escolha uma data dentro do período da despesa.";
    - `func build() -> ExpenseEntry`.
  - `ExpenseStore`:
    - `saveEntry(_ draft: ExpenseEntryDraft) async -> Bool`;
    - `deleteEntry(_ entry: ExpenseEntry) async -> Bool`;
    - os dois atualizam `snapshot.entries`.

- [ ] **Step 1: Testes que falham**

  - `paymentWithPartsSumsParts`: o condomínio com partes 820, 110 e 80, pago, grava `paidParts` com os 3 valores e `paidAmount` 1010.
  - `billWithPartsKeepsPartsAndTotal`: `billSaved` grava `billParts` e `billAmount` igual à soma.
  - `partsStartFromBillWhenPaying`: com bill lançado e água 110, o draft de pagamento abre com água 110.
  - `allFixedPartsOpenPayment`: todas fixas abre em `.payment`. Uma varia, sem bill, abre em `.bill`.
  - `removingPaymentClearsPaidParts`.
  - `ExpenseEntryDraftTests`:
    - a data padrão no mês atual é 17/10, e em setembro é 30/09;
    - data futura, data antes do início e data depois do fim dão a mensagem;
    - valor nil ou 0 dá a mensagem;
    - editar mantém o id.
  - No store, `addEditAndDeleteEntry` usa o fake e confere `snapshot.entries`. Com erro de rede, o snapshot fica igual e `errorMessage` é preenchido.

- [ ] **Step 2: Implementar e rodar a suíte completa, commit**

  `feat(despesas): lança conta por partes e gastos do mês`

---

### Task 6: Telas do cadastro e da sheet de conta

**Files:**
- Modify: `Financas/Expenses/ExpenseFormView.swift`, `ExpenseSheet.swift`
- Create: `Financas/Expenses/ExpensePartsSection.swift`, `ExpenseBillPartsSection.swift`

**Interfaces:**
- Consumes: `ExpenseDraft.kind`, `parts`, `addPart`, `removePart` (Task 4) e `ExpenseBillDraft.parts`, `partsTotal` (Task 5).

Comportamento, conforme a spec e o mockup:
- Despesa nova: seletor segmentado no topo, com "Conta com vencimento" e "Gasto do mês". Na edição, o seletor não aparece.
- Gasto do mês:
  - campos: Nome, "Previsto por mês", Início e "Tem mês de fim";
  - sem dia de vencimento e sem partes;
  - footer: "Gasto do mês não tem vencimento nem aviso. Você adiciona os gastos ao longo do mês, e eles já contam como pagos."
- Conta:
  - seção "Partes", com uma linha por parte: campo de nome, seletor Fixo/Varia compacto e valor;
  - "Adicionar parte" e apagar por swipe ou pelo botão de remover;
  - sem partes, o seletor Fixo/Varia e o valor da despesa aparecem como hoje;
  - com partes, os dois somem;
  - footer da seção: "Sem partes, a despesa tem um valor só. Com partes, o valor previsto é a soma delas."
- Sheet de conta com partes:
  - nos dois modos, um campo de valor por parte e uma linha "Total" com `partsTotal`, só leitura;
  - os campos "Valor da conta" e "Valor pago" não aparecem;
  - o vencimento (modo conta) e a data do pagamento (modo pagamento) continuam.

- [ ] **Step 1: Implementar, `xcodegen generate`, build e suíte completa**
- [ ] **Step 2: Conferir no simulador com dados de preview ou harness temporário (não commitar o harness), commit**

  `feat(despesas): mostra partes e tipo no cadastro e na conta`

---

### Task 6b: Ciclo próprio de cada parte — banco, modelos e cálculo

Mudança de escopo pedida pelo dono depois da Task 6: cada parte tem vencimento, conta lançada e
pagamento próprios (spec, "Ciclo de cada parte", "A despesa com partes no mês", "Atrasadas, avisos e
Home"). Esta task troca o registro de partes em `jsonb` por uma tabela própria e leva o ciclo ao cálculo.

**Files:**
- Modify: `supabase/migrations/20261018010000_add_expense_parts_and_entries.sql` (ainda não aplicada)
- Create: `Financas/Expenses/ExpensePartBill.swift`
- Modify: `ExpenseBill.swift` (remove `billParts`/`paidParts`), `ExpensePartTerm.swift`, `ExpenseSnapshot.swift`, `ExpenseService.swift`, `SupabaseExpenseService.swift`, `ExpenseConstants.swift`, `ExpensePartSchedule.swift`, `ExpensePartValue.swift`, `ExpenseOccurrence.swift`, `ExpenseSchedule.swift`, `ExpenseStore.swift`, `ExpenseDraft.swift`, `ExpensePartDraft.swift`, `Financas/Home/HomeMonthSummary.swift`, `FinancasTests/Fakes.swift`
- Os call sites de `billParts`/`paidParts` em `ExpenseBillDraft` passam a compilar contra o novo modelo de forma mínima; o fluxo de conta inteira e de uma parte é refeito na Task 6c.
- Test: `ExpensePartScheduleTests`, `ExpenseScheduleTests`, `ExpenseCodingTests`, `ExpenseDraftTests`, `HomeMonthSummaryTests`, `ExpenseStoreTests`

**Interfaces:**
- Produces:
  - Migration: remove `bill_parts`/`paid_parts`; `expense_part_terms.day_of_month smallint check (day_of_month between 1 and 31)` (nulo = dia da despesa); tabela `expense_part_bills` (`id`, `user_id`, `part_id` cascade, `month` dia 1, `bill_amount`, `bill_due_date`, `paid_on`, `paid_amount` com os mesmos checks de `expense_bills`, `unique (part_id, month)`), RLS no padrão, insert/update checando o dono via `expense_parts`.
  - `struct ExpensePartBill: Identifiable, Hashable, Codable, Sendable { let id: UUID; let partID: UUID; let month: YearMonth; var billAmount: Decimal?; var billDueDate: CalendarDay?; var paidOn: CalendarDay?; var paidAmount: Decimal?; var isEmpty: Bool }` (encode com nulls, como `ExpenseBill`).
  - `ExpensePartTerm.dayOfMonth: Int?` (coluna `day_of_month`).
  - `ExpenseSnapshot.partBills: [ExpensePartBill] = []`.
  - `ExpenseService.save(_ partBills: [ExpensePartBill])` (upsert em lote, `onConflict: "part_id,month"`) e `deletePartBills(ids: [UUID])`; fake registra `savePartBills`/`deletePartBills`.
  - `ExpensePartValue` ganha `month: YearMonth`, `dueDate: CalendarDay`, `bill: ExpensePartBill?`, `status: ExpenseStatus`; `id` passa a ser `"\(part.id)-\(month.year)-\(month.month)"` (String).
  - `ExpensePartSchedule.values(of:in:snapshot:today:)` (ganha `today`). Regras 1–2 leem `partBills` da parte no mês; a média lê `paidAmount` de `partBills`. `dueDate`: `bill.billDueDate`, senão próximo dia útil do dia vigente da parte (`dayOfMonth ?? dia do term da despesa`). `change` lê `partBills`.
  - `ExpenseOccurrence`: `remaining: Decimal` (sem partes: 0 se paga, senão `amount`; com partes: soma das partes sem pagamento) e `isPartiallyPaid: Bool` (alguma parte paga e alguma em aberto).
  - `ExpenseSchedule.occurrence` com partes ativas: `amount` = soma das partes; status agregado (paga se todas pagas; atrasada se alguma atrasada; senão pendente); `dueDate` = menor vencimento das partes em aberto, ou o maior se todas pagas; `bill` continua sendo o `ExpenseBill` do mês (não usado pelas partes).
  - `ExpenseSchedule.summary`: `paid` soma o `paidAmount` das partes pagas no mês (e dos bills como hoje); `remaining` soma `remaining`.
  - `ExpenseStore.overdueTotal` usa `remaining`.
  - `HomeMonthSummary`: cada `ExpensePartBill` pago no mês é saída na data e `HomeEntry(title: "\(despesa) · \(parte)")`.
  - `ExpenseDraft`: `ExpensePartDraft.dayOfMonth: Int?` (edição: o do term vigente); mudar o dia gera term novo da parte e mantém `averageFrom`. O "mês atual já registrado" passa a considerar também `partBills` das partes da despesa no mês atual.

- [ ] **Step 1: Testes que falham**
  - `partDueDateUsesOwnDay`: Água com `dayOfMonth` 15 vence 2026-10-15; Taxa sem dia usa o dia da despesa.
  - `partBillOverridesDueDateAndAmount`: `ExpensePartBill` de Água em outubro com conta 110 vencendo 20/10 → valor 110 `.bill`, vencimento 20/10.
  - `partStatusPaidOverdueAndPending`: hoje 17/10; Taxa paga, Água vencida em 15/10, Gás vence 26/10 → `.paid`, `.overdue`, `.pending`.
  - `occurrenceAggregatesPartStatus`: com o caso acima, ocorrência `.overdue`, `isPartiallyPaid` true, `remaining` = água + gás, `dueDate` 15/10; todas pagas → `.paid`, `remaining` 0.
  - `summaryUsesRemainingAndPartPayments`: `paid` inclui a taxa paga, `remaining` só água + gás.
  - `carriedWhileAnyPartOpen`: setembro com uma parte em aberto vencida aparece em `carried` em outubro; pagando a parte, some.
  - `averageReadsPartBills`: média da Água a partir de 3 `ExpensePartBill` pagos.
  - Coding: `ExpensePartBill` codifica nulls e `month` como `"2026-10-01"`; `ExpensePartTerm` decodifica `day_of_month` nulo e 15.
  - Home: `partPaymentsAreEntries` com título "Condomínio · Água".
  - Draft: `changingPartDayCreatesTermKeepingAverage`; `currentMonthWithPartPaymentIsRegistered`.
  - Os testes de partes existentes que liam `billParts`/`paidParts` passam a montar `ExpensePartBill`, com as mesmas asserções de valor.

- [ ] **Step 2: Implementar, `xcodegen generate`, suíte completa, commit**

`feat(despesas): dá vencimento e pagamento próprios a cada parte`

---

### Task 6c: Lançar e pagar por parte, Atrasadas e avisos por parte

**Files:**
- Create: `Financas/Expenses/ExpensePayable.swift`, `ExpensePartBillDraft.swift`
- Modify: `ExpenseBillDraft.swift`, `ExpenseBillPartDraft.swift`, `ExpenseSheet.swift`, `ExpenseSheetTarget.swift`, `ExpenseFlow.swift`, `ExpenseBillPartsSection.swift`, `ExpensePartsSection.swift`, `ExpenseStore.swift`, `ExpenseOccurrenceRow.swift`, `Financas/Reminders/OverdueView.swift`, `OverdueSummary.swift`, `OverdueExpenseRow.swift`, `DueItem+Expense.swift`, `Financas/Home/HomeStats.swift`, `Financas/Home/MainTabView.swift`
- Test: `ExpenseBillDraftTests`, `ExpensePartBillDraftTests`, `ExpenseStoreTests`, `OverdueSummaryTests` (se existir), `ReminderPlannerTests` só se quebrar

**Interfaces:**
- Consumes: Task 6b.
- Produces:
  - `struct ExpensePayable: Identifiable, Hashable { let occurrence: ExpenseOccurrence; let part: ExpensePartValue?; var id: String; var title: String; var amount: Decimal; var dueDate: CalendarDay; var status: ExpenseStatus }`. Sem parte: espelha a ocorrência (`title` = `ExpenseFormat.occurrenceTitle`). Com parte: `title` = `"\(occurrenceTitle) · \(parte.name)"`, `amount`/`dueDate`/`status` da parte, `id` = id da parte no mês.
  - `ExpenseStore.overduePayables(today:) -> [ExpensePayable]` (uma por ocorrência sem partes atrasada; uma por parte atrasada), ordenadas como `overdueOccurrences` hoje. `overdueOccurrences` deixa de ser usado por Atrasadas, `HomeStats` e o badge (`MainTabView`), que passam a usar `overduePayables`. `dueItems` gera um `DueItem` por payable em aberto (partes em aberto viram itens próprios).
  - `ExpenseSheetTarget` ganha `partID: UUID?`. Com `partID`, a sheet trata só a parte (`ExpensePartBillDraft`), no formato de despesa sem partes: modo conta (valor, vencimento, "Remover conta") e pagamento (valor, data, "Desmarcar pagamento"); título `"\(despesa) · \(parte) · \(mês)"`.
  - `ExpensePartBillDraft`: `init(value: ExpensePartValue, today:, mode:)`, `billSaved()`, `paymentSaved()`, `billRemoved() -> ExpensePartBill?`, `paymentRemoved() -> ExpensePartBill?`; modo padrão: `.payment` se a parte é fixa ou tem conta lançada ou está paga, senão `.bill`.
  - `ExpenseBillDraft` (conta inteira) com partes: modo conta lista as partes sem pagamento com valor (conta lançada, senão valor calculado) e um vencimento único; `billSaved` devolve `[ExpensePartBill]` com conta lançada e esse vencimento. Modo pagamento lista as partes em aberto com valor (conta, senão calculado) e uma data única; `paymentSaved` devolve `[ExpensePartBill]` marcando todas como pagas. Partes pagas não aparecem nos campos. O `Total` soma as linhas mostradas.
  - `ExpenseStore`: `saveBill`/`markPaid` com partes chamam `service.save(partBills)`; `removeBill`/`unmarkPaid` de conta inteira com partes limpam conta/pagamento de todas as partes do mês (`deletePartBills` para as que ficam vazias, `save` para as demais); `savePartBill(_ draft: ExpensePartBillDraft, for: ExpensePayable)`, `removePartBill`, `unmarkPartPaid`. Sempre atualizam `snapshot.partBills`.
  - `ExpenseOccurrenceRow`: selo "parcialmente paga" (cor `ExpenseBadgeConstants.billTint`) quando `isPartiallyPaid` e não atrasada; com partes, o valor da linha continua o total.
  - `ExpensePartsSection` (cadastro): cada parte ganha o campo "Vence dia" opcional (Picker com "Mesmo da despesa" + 1…31).
  - Atrasadas: seção Despesas lista `overduePayables`; tocar abre a sheet (com `partID` quando houver), já em pagamento. `OverdueExpenseRow` recebe `ExpensePayable`.

- [ ] **Step 1: Testes que falham**
  - `wholeBillPaymentMarksOpenPartsOnly`: Taxa já paga; pagar a conta inteira grava `ExpensePartBill` pagos só para Água e Gás, com a data escolhida; Taxa não aparece nos campos.
  - `wholeBillLaunchSetsSharedDueDate`: lançar a conta inteira grava conta e o mesmo vencimento nas partes em aberto.
  - `partDraftDefaultsAndSaves`: parte fixa abre em pagamento; varia sem conta abre em conta; `paymentSaved` grava valor e data só da parte.
  - `overduePayablesSplitParts`: Água atrasada e Gás pendente → um payable "Condomínio · Água"; despesa sem partes atrasada → um payable com o título de hoje.
  - `dueItemsPerOpenPart`: Água e Gás em aberto → dois `DueItem` com os valores das partes.
  - Store: `markPaidWholeBillSavesPartBills`, `unmarkPartPaidKeepsOtherParts`, erro de rede mantém `partBills`.
- [ ] **Step 2: Implementar, `xcodegen generate`, suíte completa**
- [ ] **Step 3: Conferir no simulador (sheet da conta inteira, sheet da parte, cadastro com dia, Atrasadas) com harness temporário não commitado; commit**

`feat(despesas): lança e paga cada parte e mostra partes atrasadas`

---

### Task 7: Detalhe e linhas da conta com partes

**Files:**
- Create: `Financas/Expenses/ExpensePartsCard.swift`, `ExpensePartsHistoryTable.swift`, `ExpensePartsHistory.swift`
- Modify: `Financas/Expenses/ExpenseDetailView.swift`, `ExpenseDetailSummary.swift`, `ExpenseOccurrenceRow.swift`, `ExpenseRow.swift`
- Test: `FinancasTests/ExpensePartsHistoryTests.swift`

**Interfaces:**
- Consumes: `ExpensePartSchedule.values`, `change`, `ExpenseFormat.partNames`, `partCaption` (Task 2).
- Produces:
  - `struct ExpensePartsHistory: Equatable`:
    - `let columns: [ExpensePart]`: partes que aparecem em algum mês da tabela, por position;
    - `let rows: [Row]`, com `struct Row: Equatable { let month: YearMonth; let amounts: [UUID: Decimal]; let total: Decimal?; let increased: Set<UUID> }`;
    - `static func make(occurrence: ExpenseOccurrence, snapshot: ExpenseSnapshot) -> ExpensePartsHistory`.
  - Linhas: o mês da ocorrência e os anteriores até `DetailConstants.historyMonths` linhas no total, parando no início da despesa.
  - O valor de cada mês é o `paidAmount` do `ExpensePartBill`, senão o `billAmount`. O mês atual sem registro usa os valores calculados.
  - O total é a soma das partes; mês sem partes usa o `paidAmount`, senão o `billAmount` do `ExpenseBill`.
  - Um mês sem partes registradas mostra só o total.
  - `increased` traz as partes Varia cujo valor subiu em relação à linha seguinte (o mês anterior).

Comportamento:
- `ExpenseOccurrenceRow` com partes mostra a legenda `"\(data) · \(partNames)"`.
- `ExpenseRow` (Cadastradas):
  - com partes, mostra `rule` com `.parts`;
  - com `.spending`, mostra `"Gasto do mês · previsto R$ 600,00"`, e esse texto vai em `ExpenseFormat.spendingRule(_ expected: Decimal) -> String`.
- Ajuste da Task 6b/6c: os valores do histórico vêm de `ExpensePartBill` (pago, senão conta lançada) e o total do mês é a soma das partes registradas. No `ExpensePartsCard`, cada linha mostra também a situação da parte ("vence 10/10", "atrasada" em `Theme.warning`, "paga em 12/10" em `Theme.positive`) e tocar abre a sheet da parte (`ExpenseSheetTarget` com `partID`). Os botões do detalhe abrem a conta inteira.
- `ExpenseDetailView` com partes:
  - o `DetailAmountBox` continua com o total;
  - abaixo dele vem `ExpensePartsCard`, com uma linha por parte usando `partCaption`, ▲ em `Theme.warning` e ▼ em `Theme.positive`;
  - `ExpensePartsHistoryTable` substitui o `DetailHistoryList`, mostrando "—" em célula sem valor e a célula de `increased` em `Theme.warning`;
  - o `rule` do cabeçalho usa `ExpenseFormat.rule` com `.parts`.

- [ ] **Step 1: Testes do `ExpensePartsHistory` (falham)**

  - `rowsWithPartsAndIncrease`: jul a out pagos com água 82, 78, 80 e 110. As linhas vêm out, set, ago e jul. `increased` de out contém água, e o de set não.
  - `monthBeforePartsShowsOnlyTotal`: um mês pago antes das partes existirem tem `amounts` vazio e `total` igual ao pago.
  - `currentMonthWithoutRecordUsesCalculatedValues`.
- [ ] **Step 2: Implementar, build, suíte completa, conferir no simulador, commit**

  `feat(despesas): mostra as partes no detalhe e o histórico por parte`

---

### Task 8: Telas do gasto do mês

**Files:**
- Create: `Financas/Expenses/SpendingRow.swift`, `SpendingDetailView.swift`, `SpendingEntrySheet.swift`, `SpendingHistoryChart.swift`, `Financas/Shared/DetailRoute+SpendingMonth.swift`
- Modify:
  - `Financas/Shared/DetailRoute.swift`, `DetailRoute+OccurrenceID.swift`, `DetailRoute+Section.swift`, `DetailRouteView.swift`;
  - `Financas/Expenses/ExpensesView.swift`;
  - `Financas/Home/HomeExpenseListCard.swift`.
- Test: `FinancasTests/DetailRouteTests.swift` (criar se não existir)

**Interfaces:**
- Consumes: `ExpenseStore.spendings`, `spendingHistory`, `saveEntry`, `deleteEntry` e `ExpenseEntryDraft` (Tasks 3 e 5).
- Produces: `DetailRoute.spending(id: String, month: YearMonth)` com `init(_ spending: SpendingMonth)`. A seção é `.expenses`, e `occurrenceID` é o id do `SpendingMonth`.

Comportamento, conforme a spec e o mockup:
- `ExpensesView`:
  - a seção "Gastos do mês" fica acima de "A pagar", com `SpendingRow` em `DetailRowList`;
  - as rotas de gastos entram antes das de ocorrências em `routes`, mas não em `openRoutes`. Assim, a seleção padrão continua sendo a primeira conta pendente;
  - o estado vazio do mês considera ocorrências e gastos.
- `SpendingRow`:
  - nome e a legenda "gasto do mês · N lançamentos" (1: "1 lançamento"; 0: "nenhum lançamento");
  - barra de `spent / expected`, limitada a 1;
  - à direita, o valor gasto e a legenda "de R$ 600,00";
  - acima do previsto, o valor e a barra ficam em `Theme.warning`.
- `SpendingDetailView`, dentro do `DetailScaffold`:
  - cabeçalho com `rule` `"Gasto do mês · previsto R$ 600"` e o título com o nome;
  - card "Gasto em \(mês)" com o valor, "de R$ 600,00", a barra e uma legenda:
    - "Faltam R$ 180,00 do previsto";
    - ou "R$ 50,00 acima do previsto", em `Theme.warning`;
    - em mês passado sem excesso, "Previsto R$ 600,00";
  - `GlassPrimaryButton("Adicionar gasto")`, que não aparece em mês futuro;
  - "Lançamentos de \(mês)": linhas com a data no formato `IncomeFormat.shortDate` e o valor. Tocar edita, e arrastar apaga sem confirmação;
  - vazio: "Nenhum gasto lançado em \(mês).";
  - "Últimos meses": `SpendingHistoryChart` com Swift Charts, barras por mês e o mês da tela em `Theme.accent`, os outros em `Theme.accent.opacity(0.35)`;
  - botão Editar do cabeçalho abre o `ExpenseFormView`, como hoje.
- `SpendingEntrySheet`:
  - título "Adicionar gasto" ou "Editar gasto";
  - campos Valor e Data, com `DatePicker` em `validRange`;
  - `GlassPrimaryButton("Adicionar")` ou `"Salvar"`, mais "Apagar gasto" (destrutivo) na edição;
  - detents `.medium`.
- `HomeExpenseListCard` mostra os `SpendingRow` antes das contas, sem o botão "Pagar". Tocar abre o detalhe.

- [ ] **Step 1: Teste de rota (falha)**

  `spendingRouteSectionAndID`: `DetailRoute(spendingMonth)` tem `section == .expenses`, e `occurrenceID` é o id do mês.
- [ ] **Step 2: Implementar, `xcodegen generate`, build, suíte completa**
- [ ] **Step 3: Conferir no simulador iPhone e iPad (lista, detalhe no painel, sheet), commit**

  `feat(despesas): adiciona o gasto do mês com lançamentos`

---

### Task 9: Migration e validação manual (dono)

- [ ] **Step 1:** O controlador pede o OK do dono e aplica `20261018010000_add_expense_parts_and_entries.sql` no Supabase.
- [ ] **Step 2:** Conferir as colunas e as tabelas novas e os advisors de segurança sem aviso novo.
- [ ] **Step 3:** O dono valida no aparelho o roteiro "Manual" da spec.

### Task 10: Landing page

- [ ] **Step 1:** Em `~/Code/financas-landing`, acrescentar nos cards de funcionalidades:
  - contas divididas em partes (condomínio com água e gás, histórico mês a mês);
  - gasto do mês com lançamentos rápidos (abastecimento).

  Atualizar também o mockup do iPhone, se ele mostrar a lista de despesas. Manter o estilo atual.
- [ ] **Step 2:** Conferir com `scratchpad/snap.swift` em 1280 px e 390 px, mostrar o diff ao dono e publicar (commit e push na `main`) só com o OK dele.
