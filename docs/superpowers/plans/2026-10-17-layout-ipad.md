# Layout para iPad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No iPad (largura regular), barra lateral recolhível com botão próprio embaixo, Home como painel do mês em duas ou três colunas, e Receitas, Despesas e Atrasadas com lista e detalhe ao lado; detalhe novo também no iPhone.

**Architecture:** A lógica que decide layout, seleção padrão, contadores e textos do detalhe fica em tipos puros testáveis (`LayoutMode`, `HomeLayout`, `DetailSelection`, `SidebarCounts`, `DueText`, `IncomeDetailSummary`, `ExpenseDetailSummary`). As views novas leem esses tipos e reaproveitam os flows de sheet que já existem (`incomeReceiptFlow`, `expenseFlow`). A navegação ganha um `AppNavigation` observável (seção atual, barra aberta e seleção pedida pela Home) no lugar do `@State selectedTab` do `MainTabView`.

**Tech Stack:** Swift 6, SwiftUI (iOS 26, SDK 27.1), Charts, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-17-layout-ipad-design.md`. Mockup: `docs/superpowers/mockups/2026-10-17-layout-ipad.html`. Spec de base: `docs/superpowers/specs/2026-10-17-despesas-fixas-design.md`.

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift`, types em arquivo próprio.
- Textos da interface em português, exatamente como a spec fixa.
- O layout depende da largura, nunca do modelo do aparelho. "Horizontal" e "vertical" = forma da janela (largura > altura), não orientação do aparelho.
- No compacto (`horizontalSizeClass == .compact`) o app continua como hoje, exceto o toque na linha, que abre o detalhe (Task 3).
- Mesmo visual: `AppBackground`, `.glassEffect(.regular, in: .rect(cornerRadius: 26))`, `MonthPicker`, `Theme`, `monospacedDigit()`. Sem ícones nas linhas.
- O detalhe não duplica regra de receber, pagar ou lançar: abre `ReceiptSheet`/`ExpenseSheet` pelos flows existentes e chama `IncomeStore.unmarkReceived(_:)` e `ExpenseStore.unmarkPaid(_:for:)`.
- O app não usa `alert`.
- Testes: `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FinancasTests/<Suite> -quiet`. Suíte completa: sem `-only-testing`.
- Arquivo novo exige `xcodegen generate` antes do build.
- Simulador de iPad para conferência: `iPad Pro 11-inch (M4)` e `iPad Pro 13-inch (M4)`.
- Commit só com aprovação explícita do dono, Conventional Commits em português, sem trailer de atribuição. Nunca push.

## Review Focus

- Selecionar uma receita no painel, marcar como recebida e voltar: o painel continua na mesma ocorrência, agora recebida, e não pula para outra. Teste em Task 1 (`keepsCurrentSelectionWhenStillPresent`).
- Trocar o mês com um item selecionado que não existe no mês novo: seleção vai para a primeira pendente do mês novo, não fica num id órfão com painel vazio. Teste em Task 1 (`fallsBackWhenSelectionMissing`).
- Ocorrência carregada de mês anterior (atrasada ou que vence neste mês) no mês atual: o detalhe mostra o mês de referência e o histórico conta a partir do mês da ocorrência, não do mês selecionado. Teste em Task 2 (`historyCountsFromOccurrenceMonth`).
- Receita que começou há menos de três meses: "Últimos meses" mostra só os meses desde o início, sem linhas vazias antes. Teste em Task 2 (`historySkipsMonthsBeforeStart`).
- Abrir e recolher a barra várias vezes ou girar o iPad: mês selecionado e item selecionado continuam. Conferência manual na Task 7, passo 2.

---

### Task 1: Decisões de layout, seleção e contadores

**Files:**
- Create: `Financas/Shared/LayoutMode.swift`, `Financas/Home/HomeLayout.swift`, `Financas/Shared/DetailSelection.swift`, `Financas/Shared/SidebarCounts.swift`
- Modify: `Financas/Shared/LayoutConstants.swift`
- Test: `FinancasTests/LayoutModeTests.swift`, `FinancasTests/DetailSelectionTests.swift`, `FinancasTests/SidebarCountsTests.swift`

**Interfaces:**
- Produces:
  - `enum LayoutMode: Equatable { case compact, regularPortrait, regularLandscape }` com `static func make(isRegular: Bool, size: CGSize) -> LayoutMode` (regular e `size.width > size.height` → `regularLandscape`).
  - `LayoutMode.showsDetailPanel(contentWidth: CGFloat) -> Bool`: `true` só em `regularLandscape` com `contentWidth >= LayoutConstants.detailPanelMinWidth`.
  - `enum HomeLayout { static func columns(contentWidth: CGFloat) -> Int }`: 3 se `contentWidth >= LayoutConstants.homeThreeColumnMinWidth`, senão 2.
  - `LayoutConstants.detailPanelMinWidth: CGFloat = 700`, `LayoutConstants.homeThreeColumnMinWidth: CGFloat = 1100`, `LayoutConstants.sidebarWidth: CGFloat = 300`.
  - `enum DetailSelection { static func resolve(current: String?, ids: [String], openIDs: [String]) -> String? }`: mantém `current` se estiver em `ids`; senão o primeiro de `openIDs`; senão o primeiro de `ids`; senão `nil`.
  - `struct SidebarCounts: Equatable { let incomes: Int; let expenses: Int; let overdue: Int }` com `init(incomes: [IncomeOccurrence], expenses: [ExpenseOccurrence], overdue: Int)`: conta status diferente de `.received` / `.paid`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func compactIgnoresSize() {
    #expect(LayoutMode.make(isRegular: false, size: CGSize(width: 1210, height: 834)) == .compact)
}
@Test func regularUsesWindowShape() {
    #expect(LayoutMode.make(isRegular: true, size: CGSize(width: 1210, height: 834)) == .regularLandscape)
    #expect(LayoutMode.make(isRegular: true, size: CGSize(width: 1032, height: 1376)) == .regularPortrait)
}
@Test func detailPanelOnlyInWideLandscape() {
    #expect(LayoutMode.regularLandscape.showsDetailPanel(contentWidth: 890))
    #expect(!LayoutMode.regularLandscape.showsDetailPanel(contentWidth: 600))
    #expect(!LayoutMode.regularPortrait.showsDetailPanel(contentWidth: 1032))
    #expect(!LayoutMode.compact.showsDetailPanel(contentWidth: 1000))
}
@Test func homeColumnsByContentWidth() {
    #expect(HomeLayout.columns(contentWidth: 890) == 2)
    #expect(HomeLayout.columns(contentWidth: 1056) == 2)
    #expect(HomeLayout.columns(contentWidth: 1210) == 3)
    #expect(HomeLayout.columns(contentWidth: 1376) == 3)
}

@Test func picksFirstOpen() {
    #expect(DetailSelection.resolve(current: nil, ids: ["a", "b", "c"], openIDs: ["b", "c"]) == "b")
}
@Test func picksFirstWhenNothingOpen() {
    #expect(DetailSelection.resolve(current: nil, ids: ["a", "b"], openIDs: []) == "a")
}
@Test func emptyListSelectsNothing() {
    #expect(DetailSelection.resolve(current: "a", ids: [], openIDs: []) == nil)
}
@Test func keepsCurrentSelectionWhenStillPresent() {
    #expect(DetailSelection.resolve(current: "c", ids: ["a", "b", "c"], openIDs: ["a"]) == "c")
}
@Test func fallsBackWhenSelectionMissing() {
    #expect(DetailSelection.resolve(current: "old", ids: ["a", "b"], openIDs: ["b"]) == "b")
}
```

`SidebarCountsTests.countsOpenOnly`: monta receitas com `IncomeSchedule.occurrences(in: S.month(2026, 10), snapshot:, today: IncomeSamples.today)` sobre `IncomeSamples.snapshot` com `receipt(IncomeSamples.fixed, outubro, amount: 100)` → `incomes == 1`; despesas com `ExpenseSchedule.occurrences(in: outubro, snapshot:, today: ExpenseSamples.today)` sobre `ExpenseSamples.snapshot` com `paid(condominio, outubro, 1150, on: 9/10)` → `expenses == 2`; `overdue: 4` → `overdue == 4`.

- [ ] **Step 2: Run to verify they fail**

Run: `xcodegen generate` e a suíte com `-only-testing:FinancasTests/LayoutModeTests -only-testing:FinancasTests/DetailSelectionTests -only-testing:FinancasTests/SidebarCountsTests`
Expected: FAIL, tipos não existem.

- [ ] **Step 3: Implement the types above**

- [ ] **Step 4: Run to verify they pass**

Mesmo comando. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Financas/Shared Financas/Home/HomeLayout.swift FinancasTests project.yml
git commit -m "feat(ipad): decide layout, seleção padrão e contadores da barra"
```

---

### Task 2: Conteúdo do detalhe

**Files:**
- Create: `Financas/Shared/DueText.swift`, `Financas/Shared/DetailHistoryEntry.swift`, `Financas/Income/IncomeDetailSummary.swift`, `Financas/Expenses/ExpenseDetailSummary.swift`
- Test: `FinancasTests/DueTextTests.swift`, `FinancasTests/IncomeDetailSummaryTests.swift`, `FinancasTests/ExpenseDetailSummaryTests.swift`

**Interfaces:**
- Produces:
  - `enum DueText { static func text(dueDate: CalendarDay, today: CalendarDay) -> String }` usando `CalendarDay.days(until:)`.
  - `struct DetailHistoryEntry: Equatable, Identifiable { let month: YearMonth; let amount: Decimal?; var id: YearMonth { month } }`. `amount == nil` = não recebida / não paga.
  - `struct IncomeDetailSummary: Equatable { let rule: String; let current: IncomeAmount?; let history: [DetailHistoryEntry] }` com `static func make(occurrence: IncomeOccurrence, snapshot: IncomeSnapshot, today: CalendarDay) -> IncomeDetailSummary`.
  - `struct ExpenseDetailSummary: Equatable { let rule: String; let history: [DetailHistoryEntry] }` com `static func make(occurrence: ExpenseOccurrence, snapshot: ExpenseSnapshot) -> ExpenseDetailSummary`.

Regras:
- `rule` de receita: `"Receita \(kind.title.lowercased()) · todo dia \(dayOfMonth)"` para fixa e por hora; avulsa: `"Receita avulsa · \(IncomeFormat.shortDate(oneOffDate))"`.
- `current` de receita: a vigência (`IncomeAmount`) com maior `validFrom <= today.yearMonth`; `nil` em avulsa. A view mostra `"desde \(mês abreviado)/\(ano)"`.
- `rule` de despesa: `"Despesa fixa · vence dia \(term.dayOfMonth)"` com `ExpenseSchedule.term(for:in: occurrence.month, snapshot:)`.
- `history`: os 3 meses anteriores a `occurrence.month`, do mais recente para o mais antigo, sem meses antes do início (`startMonth`), com o valor recebido (`IncomeReceipt.amount`) ou pago (`ExpenseBill.paidAmount`). Avulsa: `[]`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func dueTexts() {
    let today = CalendarDay(year: 2026, month: 10, day: 17)
    #expect(DueText.text(dueDate: today, today: today) == "vence hoje")
    #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 18), today: today) == "vence 18/10 · daqui a 1 dia")
    #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 25), today: today) == "vence 25/10 · daqui a 8 dias")
    #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 16), today: today) == "atrasada há 1 dia")
    #expect(DueText.text(dueDate: CalendarDay(year: 2026, month: 10, day: 13), today: today) == "atrasada há 4 dias")
}
```

Conferir o formato de data com `IncomeFormat.shortDate`; se ele não produzir `25/10`, o teste usa o que ele produz.

`IncomeDetailSummaryTests` (receita fixa "Salário", dia 5, início 2026-07, vigências 6.800 desde 2026-07 e 7.150 desde 2026-11):
- `ruleAndCurrent`: ocorrência de outubro, `today` 17/10 → `rule == "Receita fixa · todo dia 5"`, `current?.amount == 6800`, `current?.validFrom == 2026-07`.
- `historyMarksMissingMonths`: recebimentos em julho (6.800) e setembro (7.150), ocorrência de outubro → `history == [set: 7150, ago: nil, jul: 6800]`.
- `historySkipsMonthsBeforeStart`: mesma receita com início 2026-09, ocorrência de outubro → `history.map(\.month) == [2026-09]`.
- `historyCountsFromOccurrenceMonth`: ocorrência de setembro (carregada para outubro, atrasada) → `history.map(\.month) == [2026-08, 2026-07]`.
- `oneOffHasNoCurrentNorHistory`: avulsa de 12/10 → `rule == "Receita avulsa · 12/10"`, `current == nil`, `history.isEmpty`.

`ExpenseDetailSummaryTests` com `ExpenseSamples`:
- `ruleUsesTermDay`: luz em outubro → `rule == "Despesa fixa · vence dia 13"`.
- `historyUsesPaidAmounts`: luz paga em julho (196,40) e setembro (219,80), ocorrência de outubro → `[set: 219.80, ago: nil, jul: 196.40]`.

- [ ] **Step 2: Run to verify they fail**

Run: `xcodegen generate` e `-only-testing:` nas três suítes. Expected: FAIL.

- [ ] **Step 3: Implement the four types**

- [ ] **Step 4: Run to verify they pass**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(detalhe): monta regra, vencimento e últimos meses de receitas e despesas"
```

---

### Task 3: Telas de detalhe e toque na linha no iPhone

**Files:**
- Create: `Financas/Shared/DetailRoute.swift`, `Financas/Income/IncomeDetailView.swift`, `Financas/Expenses/ExpenseDetailView.swift`, `Financas/Shared/DetailAmountBox.swift`, `Financas/Shared/DetailHistoryList.swift`
- Modify: `Financas/Income/IncomesView.swift`, `Financas/Expenses/ExpensesView.swift`, `Financas/Reminders/OverdueView.swift`

**Interfaces:**
- Consumes: `IncomeDetailSummary.make`, `ExpenseDetailSummary.make`, `DueText.text`, `DetailHistoryEntry` (Task 2); `ExpenseFormat.origin`, `ExpenseFormat.occurrenceTitle`, `IncomeFormat.occurrenceTitle`.
- Produces:
  - `enum DetailRoute: Hashable { case income(id: String, month: YearMonth); case expense(id: String, month: YearMonth) }`.
  - `IncomeDetailView(occurrenceID: String, month: YearMonth)` e `ExpenseDetailView(occurrenceID: String, month: YearMonth)`. Cada uma busca a ocorrência viva em `store.occurrences(in: month)` (despesa: `occurrences(in:today:)` com `incomeStore.today`), então mostra o estado novo depois de salvar. Sem ocorrência (excluída), mostra "Não encontrada" e nada mais.
  - Cada view tem o próprio `@State` de `receiving`/`paying`/`editing` e aplica `incomeReceiptFlow`/`expenseFlow`.

Conteúdo, conforme a seção "Detalhe" da spec:
- Receita: cabeçalho com `summary.rule`, título com `IncomeFormat.occurrenceTitle` e botão "Editar". Bloco do valor: pendente ou atrasada, "Previsto para \(mês)" + `expectedAmount` + `DueText`; recebida, "Recebido em \(mês)" em `Theme.positive` + "em \(data) · como previsto" ou "em \(data) · previsto \(valor)". Bloco "Valor atual" + "desde \(mmm/aaaa)" quando `current != nil`. Ações: pendente ou atrasada, botão principal "Marcar como recebida" (abre `ReceiptSheet`); recebida, "Alterar recebimento" (abre `ReceiptSheet`) e "Desmarcar recebimento" destrutivo (`unmarkReceived`). "Últimos meses" com "não recebida" para `nil`, só quando `history` não está vazio.
- Despesa: cabeçalho com `summary.rule`, título com `ExpenseFormat.occurrenceTitle` e botão "Editar". Bloco do valor: `occurrence.amount` + `ExpenseFormat.origin`; paga em `Theme.positive`. Bloco "Vencimento": `IncomeFormat.shortDate(dueDate)` + `DueText` (sem esse bloco quando paga). Ações: não paga, principal "Marcar como paga" (`.payment`) e secundária "Lançar valor da conta" ou, com `hasBill`, "Alterar conta lançada" (`.bill`); paga, "Alterar pagamento" (`.payment`) e "Desmarcar pagamento" destrutivo (`unmarkPaid(ExpenseBillDraft(occurrence:today:), for:)`). "Últimos meses" com "não paga" para `nil`.
- `errorMessage` do store aparece no detalhe em `Theme.warning`, como nas listas.

Listas, só no compacto nesta task:
- Em `IncomesView`, `ExpensesView` e `OverdueView`, o `Button` da linha de ocorrência vira `NavigationLink(value: DetailRoute...)`, com `.navigationDestination(for: DetailRoute.self)`. O `month` é o mês da lista (`selectedMonth`; em Atrasadas, `today.yearMonth`). O `contextMenu` de editar continua. As linhas de "Cadastradas" continuam abrindo o formulário.

- [ ] **Step 1: Implementar `DetailRoute`, `DetailAmountBox`, `DetailHistoryList`, `IncomeDetailView`, `ExpenseDetailView`**

- [ ] **Step 2: Trocar o toque nas três listas**

- [ ] **Step 3: Build e suíte completa**

Run: `xcodegen generate`, build e suíte completa. Expected: build sem warning novo e suíte PASS.

- [ ] **Step 4: Conferir no iPhone 16 Pro Max**

Rodar o app com o fake ou com a conta de teste. Tocar numa receita pendente abre o detalhe por push. "Marcar como recebida" abre a sheet, e salvar volta ao detalhe já recebido. "Desmarcar recebimento" volta a pendente. Repetir com uma despesa: lançar conta, pagar, desmarcar. Em Atrasadas, tocar abre o detalhe. Tirar screenshot de cada detalhe para o revisor.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(detalhe): abre o detalhe de receitas e despesas ao tocar na linha"
```

---

### Task 4: Barra lateral recolhível

**Files:**
- Create: `Financas/Home/AppNavigation.swift`, `Financas/Home/AppSidebarHeader.swift`, `Financas/Home/AppSidebarFooter.swift`, `Financas/Home/AccountMenu.swift`, `Financas/Home/SidebarToggleButton.swift`, `Financas/Home/NavigationConstants.swift`
- Modify: `Financas/Home/MainTabView.swift`, `Financas/Home/HomeView.swift`, `Financas/FinancasApp.swift` (injeção do `AppNavigation`)
- Test: `FinancasTests/AppNavigationTests.swift`

**Interfaces:**
- Consumes: `LayoutMode`, `SidebarCounts`, `LayoutConstants.sidebarWidth` (Task 1).
- Produces:
  - `@MainActor @Observable final class AppNavigation` com `init(defaults: UserDefaults = .standard)`, `var section: AppTab`, `var isSidebarOpen: Bool`, `var pendingSelection: DetailRoute?`, `func open(_ route: DetailRoute)` (troca `section` para `.incomes`/`.expenses` e guarda `pendingSelection`), `func takeSelection(for section: AppTab) -> DetailRoute?` (devolve e limpa quando é da seção pedida).
  - `isSidebarOpen` lembrado em `UserDefaults` (chave em `NavigationConstants.sidebarOpenKey`, padrão `true`) e usado só em `regularLandscape`. Em `regularPortrait`, a barra começa recolhida a cada vez que a janela fica vertical.
  - `AccountMenu`: o `Menu` de hoje da toolbar da Home (foto, Configurações, Bloquear, Sair da conta, com o `confirmationDialog` e o `photosPicker`), extraído para ser usado na Home e no pé da barra.
  - `HomeView` deixa de receber `@Binding selectedTab` e passa a usar `AppNavigation`. No compacto e com a barra recolhida, o avatar continua na toolbar. Com a barra aberta, sai da toolbar.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func openRouteSwitchesSection() {
    let nav = AppNavigation(defaults: UserDefaults(suiteName: #function)!)
    nav.open(.expense(id: "x", month: YearMonth(year: 2026, month: 10)))
    #expect(nav.section == .expenses)
    #expect(nav.takeSelection(for: .incomes) == nil)
    #expect(nav.takeSelection(for: .expenses) == .expense(id: "x", month: YearMonth(year: 2026, month: 10)))
    #expect(nav.takeSelection(for: .expenses) == nil)
}
@Test func sidebarStateIsRemembered() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    #expect(AppNavigation(defaults: defaults).isSidebarOpen)
    AppNavigation(defaults: defaults).isSidebarOpen = false
    #expect(!AppNavigation(defaults: defaults).isSidebarOpen)
}
```

- [ ] **Step 2: Run to verify they fail, implement `AppNavigation`, run to verify they pass**

- [ ] **Step 3: Spike do controle da barra (descartável, no simulador de iPad)**

O SDK não tem binding de visibilidade da barra no `TabView`. Testar nesta ordem:
- (a) `TabView` com `.tabViewStyle(.sidebarAdaptable)`, `.defaultAdaptableTabBarPlacement(nav.isSidebarOpen ? .sidebar : .tabBar)` e `.toolbar(removing: .sidebarToggle)`. Trocar `isSidebarOpen` por um botão e ver se a barra abre e fecha na hora, e se o botão do sistema some.
- (b) Se (a) não reagir, repetir com `.id(nav.isSidebarOpen)` no `TabView` e ver se o estado das abas (mês, scroll, item selecionado) sobrevive. Não pode perder o mês.
- (c) Se (a) e (b) falharem: `NavigationSplitView(columnVisibility:)` com `.toolbar(removing: .sidebarToggle)`, barra feita à mão com a lista das seções e, recolhida, uma barra de abas própria no topo: cápsula de vidro com os quatro ícones e o badge, como `tabtop` no mockup.

Registrar no relatório qual opção ficou e por quê. Se nenhuma esconder o botão do sistema, parar e avisar o dono (spec, "Navegação").

- [ ] **Step 4: Implementar a navegação com a opção escolhida**

- Compacto: abas embaixo como hoje, com `.tabBarMinimizeBehavior(.onScrollDown)`.
- Regular: barra com `AppSidebarHeader` (`AppMark` de 32pt e "Finanças"), as quatro seções com ícone e nome, contadores de `SidebarCounts` montados com `incomeStore.occurrences(in: selectedMonth)`, `expenseStore.occurrences(in: selectedMonth, today:)` e o mesmo total do badge de hoje (Atrasadas em `Theme.warning`; zero não aparece) e `AppSidebarFooter` (avatar, nome, "Conta e configurações", abre `AccountMenu`).
- `SidebarToggleButton`: botão redondo de vidro de 48pt, `systemImage: "sidebar.left"`, `accessibilityLabel` "Mostrar barra lateral" / "Esconder barra lateral". Com a barra recolhida, flutua no canto inferior esquerdo, com 24pt de margem. Com a barra aberta, fica no pé da barra, ao lado do avatar.
- `MainTabView` lê `LayoutMode` por `GeometryReader` + `horizontalSizeClass` e fecha a barra quando entra em `regularPortrait`.
- `applyPendingRoute` passa a trocar `nav.section`.

- [ ] **Step 5: Build, suíte e conferência**

Suíte completa PASS. No iPad Pro 11" na horizontal: a barra abre e fecha pelo nosso botão, o botão do sistema não aparece e o estado é lembrado entre execuções. Na vertical, a barra começa recolhida. No iPhone, nada mudou. Um aviso de atraso abre Atrasadas. Screenshots dos dois estados.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(ipad): troca as abas por barra lateral recolhível no iPad"
```

---

### Task 5: Lista e detalhe lado a lado

**Files:**
- Create: `Financas/Shared/ListDetailLayout.swift`
- Modify: `Financas/Income/IncomesView.swift`, `Financas/Expenses/ExpensesView.swift`, `Financas/Reminders/OverdueView.swift`, `Financas/Income/OccurrenceRow.swift`, `Financas/Expenses/ExpenseOccurrenceRow.swift`, `Financas/Reminders/OverdueRow.swift`, `Financas/Reminders/OverdueExpenseRow.swift`

**Interfaces:**
- Consumes: `LayoutMode.showsDetailPanel`, `DetailSelection.resolve` (Task 1); `DetailRoute`, `IncomeDetailView`, `ExpenseDetailView` (Task 3); `AppNavigation.takeSelection(for:)` (Task 4).
- Produces: `ListDetailLayout<List: View, Detail: View>(selection: Binding<DetailRoute?>, showsPanel: Bool, list: () -> List, detail: (DetailRoute) -> Detail)`. Com painel, `HStack` com lista e detalhe em card de vidro, proporção ~1 : 1,05 como no mockup. Sem painel, só a lista, e o detalhe vai para `.sheet(item:)`.

Comportamento:
- As linhas recebem `isSelected: Bool` e mostram fundo `Theme.accent.opacity(0.12)` com raio 14 quando selecionadas.
- Com painel, tocar seleciona. Sem painel, no regular, tocar abre a sheet. No compacto, fica o push da Task 3.
- Seleção padrão: ao aparecer e ao mudar `selectedMonth` ou o snapshot, `selection = DetailSelection.resolve(current:ids:openIDs:)`, com `ids` na ordem da tela e `openIDs` das não recebidas ou pagas. Só com painel.
- `AppNavigation.takeSelection(for:)` tem prioridade sobre a seleção padrão.
- Mês sem ocorrências: `selection == nil` e o painel mostra o mesmo texto vazio da lista ("Nenhuma receita prevista para \(mês)." / "Nenhuma despesa prevista para \(mês)."); em Atrasadas sem itens, só a lista com "Nada atrasado".
- Rotação: guardar se a seleção veio de toque (`selectedByUser`). Ao perder o painel com `selectedByUser`, abrir a sheet. Ao ganhar o painel com a sheet aberta, fechar a sheet e manter a seleção. Seleção automática não abre sheet ao girar.
- Atrasadas: lista com o card de topo e as seções Receitas e Despesas. O detalhe da despesa abre com a ação principal "Marcar como paga", que já é a principal na Task 3.
- `readableWidth(LayoutConstants.contentWidth)` só no compacto e no regular sem painel. No regular sem painel, a lista usa a largura toda menos 28pt de margem.
- Título da seção grande com o "+" à direita, como no mockup, onde a seção tem cadastro.

- [ ] **Step 1: Implementar `ListDetailLayout` e as linhas selecionáveis**

- [ ] **Step 2: Aplicar nas três telas**

- [ ] **Step 3: Build, suíte e conferência**

Suíte PASS. No iPad Pro 11" na horizontal: Receitas abre com a primeira pendente no painel, e trocar o mês seleciona a primeira pendente do mês novo. Marcar como recebida pelo painel mantém a mesma linha selecionada. Girar com uma linha tocada abre a sheet, e voltar fecha a sheet com a linha no painel. Despesas e Atrasadas fazem o mesmo. No iPad Pro 13" na vertical: lista e sheet, sem painel. No iPhone: push. Screenshots.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ipad): mostra lista e detalhe lado a lado em receitas, despesas e atrasadas"
```

---

### Task 6: Home como painel do mês

**Files:**
- Create: `Financas/Home/HomeWideView.swift`, `Financas/Home/BalanceChartCard.swift`, `Financas/Home/HomeStatCard.swift`, `Financas/Home/HomeIncomeListCard.swift`, `Financas/Home/HomeExpenseListCard.swift`
- Modify: `Financas/Home/HomeView.swift`

**Interfaces:**
- Consumes: `LayoutMode`, `HomeLayout.columns` (Task 1); `DetailRoute`, detalhes (Task 3); `AppNavigation.open(_:)` (Task 4); `HomeMonthSummary`, `IncomeStore.summary(for:)`, `ExpenseStore.summary(for:today:)`, `IncomeStore.overdueOccurrences`, `ExpenseStore.overdueOccurrences(today:)`.
- Produces:
  - `BalanceChartCard(summary: HomeMonthSummary, chartHeight: CGFloat, showsDayScale: Bool)`: o `balanceCard` de hoje extraído do `HomeView`, com a escala 1, 10, 20 e último dia opcional. A Home do iPhone passa a usá-lo com `chartHeight: 96, showsDayScale: false`.
  - `HomeStatCard(title: String, value: String, caption: String, badge: String?, tint: Color?, action: (() -> Void)?)`.

Conteúdo, conforme a seção "Home no iPad" da spec:
- `HomeView` escolhe entre o layout de hoje (compacto) e `HomeWideView` (regular).
- Barra aberta (`HomeLayout.columns == 2`): o topo tem logo, saudação e data à esquerda e o `MonthPicker` com 300pt à direita. Linha 1: `BalanceChartCard` (altura 150, com escala) e, ao lado, três `HomeStatCard` empilhados: "Falta receber" e "Falta pagar" com "de \(previsto)" e selo "N atrasada(s)", e "Atrasadas" com a quantidade em `Theme.warning` e até dois nomes separados por " · ", que abre a seção Atrasadas. Linha 2: `HomeIncomeListCard` e `HomeExpenseListCard`.
- Barra recolhida (`columns == 3`): quatro `HomeStatCard` (Saldo, Falta receber, Falta pagar, Atrasadas) e três colunas: Receitas, Despesas e `BalanceChartCard` com o título "Saldo dia a dia".
- Vertical (`regularPortrait`): `BalanceChartCard` (altura 120), os três `HomeStatCard` lado a lado e as duas listas lado a lado.
- Os cards de lista mostram título e "+ Nova" (abre o cadastro), e as ocorrências na mesma ordem das abas. As pendentes e atrasadas têm um botão "Receber" (`Theme.positive`) ou "Pagar" (accent) na linha, que abre a `ReceiptSheet` ou a `ExpenseSheet` em `.payment`. Tocar no resto da linha chama `nav.open(route)` na horizontal com painel. Na vertical, abre o detalhe em sheet na própria Home.
- O card de "Lançamentos" não entra no regular.
- Carregamento, erro e vazio usam `IncomeLoadContent`/`ExpenseLoadContent` em cada card de lista. Os `HomeStatCard` mostram "—" enquanto carregam.
- A Home rola. `readableWidth` só no compacto.

- [ ] **Step 1: Extrair `BalanceChartCard` e usá-lo no iPhone sem mudança visual**

Build e suíte PASS. Screenshot da Home do iPhone antes e depois, iguais.

- [ ] **Step 2: Implementar `HomeStatCard`, os dois cards de lista e `HomeWideView`**

- [ ] **Step 3: Build, suíte e conferência**

Suíte PASS. iPad Pro 11" na horizontal, barra aberta: duas colunas. Barra recolhida: três colunas. Na vertical: empilhado. "Receber" abre a sheet, e tocar na linha leva para Receitas com aquela linha no painel. iPad Pro 13" na horizontal, com a barra aberta: duas colunas. Modo escuro. Screenshots de cada caso.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ipad): mostra a home como painel do mês no iPad"
```

---

### Task 7: Validação final

**Files:** nenhum, a não ser correções.

- [ ] **Step 1: Suíte completa**

Run: suíte completa. Expected: PASS, sem warning novo no build.

- [ ] **Step 2: Roteiro manual da spec ("Como validar")**

- iPad Pro 11" e 13", horizontal e vertical: Home com a barra aberta e recolhida; Receitas, Despesas e Atrasadas com detalhe; botão de abrir embaixo à esquerda; botão do sistema ausente.
- Abrir e recolher a barra cinco vezes e girar com um item tocado: mês e item continuam.
- Split View com 1/3 da tela: layout do iPhone, sem cortes.
- iPhone: o fluxo de receber e desmarcar pelo detalhe.
- Aviso de atraso e de "vence hoje" tocado com o app no iPad: abre a seção certa.
- Modo escuro nas telas novas.

Registrar os screenshots e qualquer desvio no relatório.
