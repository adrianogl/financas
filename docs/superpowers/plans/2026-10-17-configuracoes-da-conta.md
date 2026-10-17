# Configurações da conta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tela de Configurações por conta com tipos de receita habilitados, regra de dia não útil e horários dos três avisos.

**Architecture:** As configurações viram `AccountSettings`, carregado junto com o `IncomeSnapshot` (tabela `account_settings` no Supabase). `IncomeSchedule` e `ReminderPlanner` passam a ler a regra e os horários dali, então a tarefa em segundo plano também respeita a configuração. O `IncomeStore` aplica a mudança no snapshot na hora, salva só as colunas alteradas e desfaz se falhar.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), Supabase Swift 2.55.4, Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-17-configuracoes-da-conta-design.md`

## Global Constraints

- Sem comentários no código. Um tipo por arquivo. Constantes em `*Constants.swift`, types em arquivo próprio.
- Textos da interface em português, como no spec.
- Padrões: os três tipos ligados; `next`; atrasadas manhã 08:00 ligado; atrasadas noite 19:00 ligado; prevista para hoje 08:00 ligado.
- Testes com Swift Testing em `FinancasTests/`. Rodar com:
  `xcodebuild test -project Financas.xcodeproj -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:FinancasTests/<Suite> -quiet`
- Arquivo novo exige `xcodegen generate` antes do build.
- Commit só com aprovação explícita do dono (CLAUDE.md). Cada passo "Commit" prepara `git add` e a mensagem proposta; os commits saem juntos no fim, depois da aprovação.
- Migration aplicada no projeto Supabase só depois de aprovação do dono.

## Review Focus

- Regra `previous` com dia 1 em fim de semana: ocorrência do mês seguinte vencendo no mês atual. Esperado: aparece como atrasada no mês atual (lista, badge, "Falta receber") e continua no mês dela. Teste na Task 2.
- Dois avisos de atraso no mesmo horário. Esperado: um aviso só. Teste na Task 3.
- Salvamento falhando (sem internet). Esperado: valor volta, mensagem aparece, avisos refeitos com o valor antigo. Teste na Task 4.
- Tentar desligar o último tipo. Esperado: impossível. Teste na Task 1.
- Conta antiga sem linha em `account_settings`. Esperado: padrões, comportamento idêntico ao de hoje. Teste na Task 1 (decode de lista vazia) e Task 2 (datas iguais às de hoje com `.standard`).

---

### Task 1: Modelo, migration e carga das configurações

**Files:**
- Create: `supabase/migrations/20261017030000_create_account_settings.sql`
- Create: `Financas/Settings/AccountSettings.swift`, `Financas/Settings/NonBusinessDayRule.swift`, `Financas/Settings/ReminderTime.swift`, `Financas/Settings/SettingsConstants.swift`
- Modify: `Financas/Income/IncomeSnapshot.swift`, `Financas/Income/SupabaseIncomeService.swift`
- Test: `FinancasTests/AccountSettingsTests.swift`

**Interfaces:**
- Produces:
  - `enum NonBusinessDayRule: String, Codable, Sendable, CaseIterable { case next, previous, keep }` com `var title: String` ("Próximo dia útil", "Dia útil anterior", "Manter a data").
  - `struct ReminderTime: Hashable, Codable, Sendable, Comparable { var hour: Int; var minute: Int }`, codifica como string `"HH:MM:SS"` e decodifica `"HH:MM"` ou `"HH:MM:SS"` (formato do `time` do Postgres).
  - `struct AccountSettings: Equatable, Codable, Sendable` com `enabledKinds: [IncomeKind]`, `nonBusinessDay: NonBusinessDayRule`, `overdueMorningEnabled: Bool`, `overdueMorningTime: ReminderTime`, `overdueEveningEnabled: Bool`, `overdueEveningTime: ReminderTime`, `dueTodayEnabled: Bool`, `dueTodayTime: ReminderTime`; `CodingKeys` em snake_case iguais às colunas; `static let standard`; `func canDisable(_ kind: IncomeKind) -> Bool`; `var orderedEnabledKinds: [IncomeKind]` (ordem de `IncomeFormConstants.kinds`); `func changedColumns(from previous: AccountSettings) -> [String: AnyJSON]` (só as colunas diferentes) em `Financas/Settings/AccountSettings+Columns.swift`, que importa `Supabase`.
  - `IncomeSnapshot.settings: AccountSettings` (default `.standard`; `IncomeSnapshot.empty` usa `.standard`).
  - `SettingsConstants.table = "account_settings"`.

- [ ] **Step 1: Escrever a migration**

Tabela conforme o spec: `user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade`; `enabled_kinds text[] not null default '{fixed,hourly,one_off}' check (cardinality(enabled_kinds) > 0 and enabled_kinds <@ array['fixed','hourly','one_off'])`; `non_business_day text not null default 'next' check (non_business_day in ('next','previous','keep'))`; três pares `*_enabled boolean not null default true` / `*_time time not null default '08:00'|'19:00'|'08:00'`; `updated_at timestamptz not null default now()`. RLS ligada, policies `account_settings_select_own`, `_insert_own`, `_update_own` no padrão de `20261016120000_create_incomes.sql`. Sem delete.

- [ ] **Step 2: Testes que falham** (`AccountSettingsTests`)

```swift
@Test func standardMatchesTodaysBehavior() {
    let s = AccountSettings.standard
    #expect(s.enabledKinds == [.fixed, .hourly, .oneOff])
    #expect(s.nonBusinessDay == .next)
    #expect(s.overdueMorningTime == ReminderTime(hour: 8, minute: 0) && s.overdueMorningEnabled)
    #expect(s.overdueEveningTime == ReminderTime(hour: 19, minute: 0) && s.overdueEveningEnabled)
    #expect(s.dueTodayTime == ReminderTime(hour: 8, minute: 0) && s.dueTodayEnabled)
}
@Test func decodesDatabaseRow() throws // JSON com "enabled_kinds":["fixed","one_off"], "non_business_day":"previous", "overdue_morning_time":"07:30:00" etc. → valores certos
@Test func decodesTimeWithoutSeconds() // "07:30" → ReminderTime(7, 30)
@Test func encodesTimeWithSeconds() // ReminderTime(7, 5) → "07:05:00"
@Test func cannotDisableLastKind() // enabledKinds [.fixed] → canDisable(.fixed) == false; [.fixed,.hourly] → true
@Test func orderedEnabledKindsFollowsFormOrder() // [.oneOff, .fixed] → [.fixed, .oneOff]
@Test func changedColumnsOnlyListsDifferences() // mudar só nonBusinessDay → chaves == ["non_business_day"]
```

- [ ] **Step 3: Rodar e ver falhar** — `-only-testing:FinancasTests/AccountSettingsTests`, esperado: erro de compilação (tipos inexistentes).

- [ ] **Step 4: Implementar os tipos e `IncomeSnapshot.settings`**

No `SupabaseIncomeService.load()`, buscar `account_settings` em paralelo com as outras três (`select().limit(1)`, decodificar `[AccountSettings]`) e usar `.first ?? .standard`.

- [ ] **Step 5: Rodar `AccountSettingsTests` e a suíte inteira** — tudo passa.

- [ ] **Step 6: Commit** — `feat(configuracoes): cria tabela e modelo de configurações da conta`

---

### Task 2: Regra de dia não útil no cálculo das datas

**Files:**
- Modify: `Financas/Income/BusinessCalendar.swift`, `Financas/Income/IncomeSchedule.swift`, `Financas/Income/IncomeStore.swift`, `Financas/Income/IncomeFormat.swift`, `Financas/Income/IncomeFormView.swift` (texto de ajuda), `Financas/Income/RecurringIncomeRow.swift` (passa a regra para `IncomeFormat.rule`)
- Test: `FinancasTests/BusinessCalendarTests.swift`, `FinancasTests/IncomeStoreTests.swift`, `FinancasTests/IncomeFormatTests.swift`

**Interfaces:**
- Consumes: `NonBusinessDayRule`, `IncomeSnapshot.settings` (Task 1).
- Produces:
  - `BusinessCalendar.businessDayOnOrBefore(_ day: CalendarDay) -> CalendarDay`
  - `BusinessCalendar.dueDate(for day: CalendarDay, rule: NonBusinessDayRule) -> CalendarDay`
  - `IncomeSchedule` usa `dueDate(for:rule: snapshot.settings.nonBusinessDay)` em Fixa e Por hora.
  - `IncomeSchedule.overdue(before:snapshot:today:)` passa a incluir as ocorrências de `month.next` com status `.overdue` (o "carried" de `occurrences(in:)` e de `summary(for:)` no mês atual).
  - `IncomeFormat.rule(for:rate:nonBusinessDay:locale:)` — sufixo " · próximo dia útil", " · dia útil anterior" ou nenhum para `keep`. Por hora continua sem o sufixo, como hoje.
  - `NonBusinessDayRule.formHint(hourly: Bool) -> String` para a ajuda do formulário: `next` mantém os textos atuais; `previous` troca por "Se o dia não for útil, cai no dia útil anterior."; `keep` por "A data fica no dia escolhido, mesmo se não for útil." Por hora acrescenta " O pagamento cobre os dias úteis do mês anterior." nos três.

- [ ] **Step 1: Testes que falham**

```swift
// BusinessCalendarTests
@Test func nextRuleMovesWeekendForward() // dueDate(2026-11-01 domingo, .next) == 2026-11-03 (02/11 é Finados)
@Test func previousRuleCrossesMonth() // dueDate(2026-11-01, .previous) == 2026-10-30
@Test func keepRuleKeepsDay() // dueDate(2026-11-01, .keep) == 2026-11-01
@Test func businessDayUnchangedByAnyRule() // 2026-10-16 (sexta) igual nas três
@Test func previousRuleSkipsHoliday() // dueDate(2026-11-15 domingo, .previous) == 2026-11-13

// IncomeStoreTests (fixa dia 1 desde 2026-10, valor 13020.04)
@Test func previousRuleCarriesNextMonthOverdueIntoCurrentMonth()
// settings.nonBusinessDay = .previous, today = 2026-10-31:
// overdueOccurrences contém a ocorrência de novembro (dueDate 2026-10-30, month 2026-11);
// summary(for: 2026-10).overdueCount inclui ela; occurrences(in: 2026-11) também a lista.
@Test func previousRuleDueTodayEntersDueItems() // today = 2026-10-30 → dueItems contém id da ocorrência de novembro
@Test func ruleDoesNotChangeOneOffOrHourlyAmount() // avulsa num sábado mantém a data; expectedAmount da Por hora igual nas três regras
@Test func standardSettingsKeepCurrentDates() // com .standard, dueDates iguais às de antes

// IncomeFormatTests
@Test func ruleTextFollowsSetting() // fixa dia 1: .next "Todo dia 1 · próximo dia útil"; .previous "Todo dia 1 · dia útil anterior"; .keep "Todo dia 1"
```

- [ ] **Step 2: Rodar e ver falhar** — suites `BusinessCalendarTests`, `IncomeStoreTests`, `IncomeFormatTests`.

- [ ] **Step 3: Implementar** — `dueDate(for:rule:)` com `businessDayOnOrAfter`, `businessDayOnOrBefore` e identidade. No carried de `overdue(before:)`, incluir `occurrences(in: month.next, ...)` filtradas por `.overdue`, sem duplicar ids (o `dueItems` já deduplica; `overdueOccurrences` precisa deduplicar também se a mesma ocorrência vier pelos dois caminhos).

- [ ] **Step 4: Rodar as três suítes e a suíte inteira** — passam.

- [ ] **Step 5: Commit** — `feat(configuracoes): aplica a regra de dia não útil nas datas das receitas`

---

### Task 3: Horários e liga/desliga dos avisos

**Files:**
- Modify: `Financas/Reminders/Reminder.swift`, `Financas/Reminders/ReminderPlanner.swift`, `Financas/Reminders/ReminderScheduler.swift`, `Financas/Reminders/SystemReminderCenter.swift`, `Financas/RootView.swift`, `Financas/FinancasApp.swift`, `Financas/Reminders/ReminderConstants.swift` (remover `morningHour`/`eveningHour`)
- Test: `FinancasTests/ReminderPlannerTests.swift`, `FinancasTests/ReminderSchedulerTests.swift`

**Interfaces:**
- Consumes: `AccountSettings`, `ReminderTime` (Task 1).
- Produces:
  - `Reminder.time: ReminderTime` no lugar de `hour`.
  - `ReminderPlanner.plan(items:settings:now:calendar:) -> [Reminder]`; ids `overdue-AAAA-MM-DD-HHMM` e `due-AAAA-MM-DD-HHMM`.
  - `ReminderScheduler.reschedule(items:settings:clearingDelivered:)`.
  - `ReminderScheduler.authorization() async -> ReminderAuthorization`.
  - `ReminderScheduler.requestPermissionFromSettings() async` — pede se `notDetermined`, ignora a marca, grava `permissionAskedKey`.
  - `RootView.syncReminders()` e `FinancasApp.refreshReminders()` passam `incomeStore.snapshot.settings`.

- [ ] **Step 1: Testes que falham** (ajustar os existentes para a nova assinatura com `.standard` e ids `-0800`/`-1900`)

```swift
@Test func disabledOverdueMorningIsNotScheduled() // overdueMorningEnabled = false → nenhum id "overdue-…-0800"
@Test func disabledDueTodayIsNotScheduled()
@Test func usesConfiguredMinutes() // dueTodayTime 07:30 → Reminder.time == ReminderTime(7, 30), id "due-2026-10-16-0730"
@Test func sameTimeOverdueBecomesOne() // manhã e noite 08:00 → um "overdue-…-0800" por dia
@Test func pastTimeTodayIsSkipped() // now 2026-10-16 07:45, dueTodayTime 07:30 → sem aviso de hoje

// ReminderSchedulerTests
@Test func settingsPermissionRequestIgnoresAskedFlag() // flag já gravada, status notDetermined → requestAuthorization chamado
@Test func settingsPermissionRequestSkipsWhenDecided() // status denied → não chama
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar** — o planner monta a lista de horários de atraso a partir dos dois ligados, sem repetir horário igual. `SystemReminderCenter` usa `reminder.time.hour` e `.minute` no `DateComponents`.

- [ ] **Step 4: Rodar `ReminderPlannerTests`, `ReminderSchedulerTests`, `BackgroundReminderRefreshTests` e a suíte inteira.**

- [ ] **Step 5: Commit** — `feat(configuracoes): usa horários e liga/desliga configurados nos avisos`

---

### Task 4: Salvar configurações

**Files:**
- Modify: `Financas/Income/IncomeService.swift`, `Financas/Income/SupabaseIncomeService.swift`, `Financas/Income/IncomeStore.swift`, `FinancasTests/Fakes.swift`
- Test: `FinancasTests/IncomeStoreSettingsTests.swift`

**Interfaces:**
- Consumes: `AccountSettings.changedColumns(from:)` (Task 1).
- Produces:
  - `IncomeService.saveSettings(_ settings: AccountSettings, previous: AccountSettings) async throws(IncomeError)`; Supabase faz `upsert` em `account_settings` com `user_id` mais as colunas alteradas, `onConflict: "user_id"`, `returning: .minimal`. Sem colunas alteradas, não chama.
  - `IncomeStore.settings: AccountSettings` (atalho para `snapshot.settings`).
  - `IncomeStore.isSavingSettings: Bool`, `IncomeStore.settingsErrorMessage: String?`.
  - `IncomeStore.updateSettings(_ new: AccountSettings) async -> Bool` — aplica em `snapshot.settings` antes de chamar o serviço; em erro, volta ao anterior e preenche `settingsErrorMessage` com `IncomeError.message`. Chamadas seguidas rodam em ordem, e cada uma compara com o valor que estava valendo quando ela começou.
  - `FakeIncomeService` registra `"saveSettings"` em `calls` e guarda `savedSettings: [(AccountSettings, AccountSettings)]`.

- [ ] **Step 1: Testes que falham**

```swift
@Test func updateAppliesImmediately() // com holdsResponses, settings já mudou antes do release
@Test func failedSaveRestoresPrevious() // nextError = .network → settings == anterior, settingsErrorMessage == IncomeError.network.message, retorna false
@Test func successfulSaveClearsError()
@Test func unchangedSettingsDoNotCallService() // updateSettings(store.settings) → calls não contém "saveSettings"
@Test func resetRestoresStandard() // após updateSettings, reset() → settings == .standard
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar.** O reagendamento vem do `.onChange(of: incomeStore.snapshot)` que já existe no `RootView`; não precisa de chamada nova.

- [ ] **Step 4: Rodar `IncomeStoreSettingsTests`, `IncomeStoreTests` e a suíte inteira.**

- [ ] **Step 5: Commit** — `feat(configuracoes): salva configurações só com as colunas alteradas`

---

### Task 5: Tipos ligados no cadastro de receita

**Files:**
- Modify: `Financas/Income/IncomeDraft.swift`, `Financas/Income/IncomeFormView.swift`, quem cria `IncomeDraft(today:)` (`IncomesView.swift`)
- Test: `FinancasTests/IncomeDraftTests.swift`

**Interfaces:**
- Consumes: `AccountSettings.orderedEnabledKinds` (Task 1), `IncomeStore.settings` (Task 4).
- Produces: `IncomeDraft(today: CalendarDay, kind: IncomeKind)`.

- [ ] **Step 1: Teste que falha**

```swift
@Test func newDraftStartsOnGivenKind() // IncomeDraft(today:, kind: .oneOff).kind == .oneOff e isNew
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar** — `IncomesView` cria o draft com `store.settings.orderedEnabledKinds.first ?? .fixed`. No `IncomeFormView`, o `Picker` usa `store.settings.orderedEnabledKinds` e só aparece se `draft.isNew` e houver mais de um tipo. A ajuda do formulário usa `store.settings.nonBusinessDay.formHint(hourly:)` (Task 2).

- [ ] **Step 4: Rodar `IncomeDraftTests` e a suíte inteira.**

- [ ] **Step 5: Commit** — `feat(configuracoes): mostra só os tipos ligados no cadastro`

---

### Task 6: Tela de Configurações

**Files:**
- Create: `Financas/Settings/SettingsView.swift`, `Financas/Settings/ReminderSettingRow.swift`, `Financas/Settings/NonBusinessDayExample.swift`
- Modify: `Financas/Home/HomeView.swift` (item "Configurações" `gearshape` acima de "Bloquear", sheet), `Financas/Settings/SettingsConstants.swift` (textos fixos se repetidos)
- Test: `FinancasTests/NonBusinessDayExampleTests.swift`

**Interfaces:**
- Consumes: `IncomeStore.settings`, `updateSettings(_:)`, `isSavingSettings`, `settingsErrorMessage`, `loadState`, `load()` (Tasks 1 e 4); `ReminderScheduler.authorization()` e `requestPermissionFromSettings()` (Task 3); `NonBusinessDayRule.title`.
- Produces: `NonBusinessDayExample.text(rule: NonBusinessDayRule) -> String` usando 1º de novembro de 2026 e `BusinessCalendar.dueDate(for:rule:)`.

- [ ] **Step 1: Teste que falha**

```swift
@Test func exampleTexts() {
    #expect(NonBusinessDayExample.text(rule: .next) == "Dia 1 de novembro de 2026 é domingo e cai em 3 de novembro.")
    #expect(NonBusinessDayExample.text(rule: .previous) == "Dia 1 de novembro de 2026 é domingo e cai em 30 de outubro.")
    #expect(NonBusinessDayExample.text(rule: .keep) == "Dia 1 de novembro de 2026 é domingo e fica nesse dia.")
}
```

- [ ] **Step 2: Rodar e ver falhar.**

- [ ] **Step 3: Implementar `NonBusinessDayExample` e a tela.**

`SettingsView` em `NavigationStack`, título "Configurações", botão "OK" (`.confirmationAction`) que fecha. Estados de `loadState` iguais à aba Receitas (carregando / erro com "Tentar de novo" chamando `load()`). `Form`:
  - "Tipos de receita": um `Toggle` por tipo em `IncomeFormConstants.kinds` com `kind.title`; desabilitado quando `!settings.canDisable(kind)` e ligado; rodapé "Pelo menos um tipo precisa ficar ligado."
  - "Dia não útil": `Picker` com `NonBusinessDayRule.allCases` e `title`; rodapé com `NonBusinessDayExample.text(rule:)`.
  - "Avisos": `ReminderSettingRow` para "Atrasadas de manhã", "Atrasadas à noite", "Prevista para hoje": `Toggle` e, ligado, `DatePicker` `.hourAndMinute`. Rodapé "Notificações estão desligadas nos Ajustes do iPhone." quando `authorization() == .denied` (lido no `.task`).
  - Mensagem `settingsErrorMessage` em `Theme.warning`, como no `IncomeFormView`.
  - Controles desabilitados enquanto `isSavingSettings`.
  - Toda mudança chama `updateSettings` com a cópia alterada; mudanças na seção Avisos chamam antes `requestPermissionFromSettings()`.

- [ ] **Step 4: Rodar `NonBusinessDayExampleTests` e a suíte inteira; build sem warnings.**

- [ ] **Step 5: Verificação manual no simulador** — com o UI test temporário do scratchpad (fakes no lugar do Supabase): abrir Configurações pelo menu do avatar, desligar Por hora e ver o seletor do cadastro sem ele; trocar a regra e ver o exemplo mudar; desligar o último tipo não é possível.

- [ ] **Step 6: Commit** — `feat(configuracoes): adiciona tela de configurações no menu do avatar`
