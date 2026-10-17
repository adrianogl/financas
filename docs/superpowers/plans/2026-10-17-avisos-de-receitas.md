# Avisos de receitas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Avisos locais de receitas atrasadas (8h e 19h) e previstas para hoje (8h), com a aba nova "Atrasadas" aberta pelo toque no aviso.

**Architecture:** Um planejador puro transforma itens com vencimento (`DueItem`) em avisos (`Reminder`) para os próximos 14 dias. Um `ReminderScheduler` pede permissão e troca os avisos agendados por meio do protocolo `ReminderCenter` (fake nos testes, `UNUserNotificationCenter` no app). O `RootView` reagenda quando o snapshot de receitas ou o dia mudam; o toque no aviso passa pelo `ReminderRouter` e troca a aba depois do desbloqueio.

**Tech Stack:** Swift 6, SwiftUI (iOS 26), UserNotifications, BackgroundTasks via `.backgroundTask(.appRefresh)`, Swift Testing, XcodeGen (`project.yml`).

**Spec:** `docs/superpowers/specs/2026-10-17-avisos-de-receitas-design.md`

## Global Constraints

- Horários fixos: 8h (atraso e "hoje") e 19h (só atraso). Janela de 14 dias. No máximo 42 avisos pendentes.
- Identificadores: `overdue-AAAA-MM-DD-08`, `overdue-AAAA-MM-DD-19`, `due-AAAA-MM-DD-08`.
- Textos exatos da tabela "Texto" da spec; valores com `IncomeFormat.currency`, data com `IncomeFormat.shortDate`, nome com `IncomeFormat.occurrenceTitle`.
- Permissão: `.alert` e `.sound`, sem badge no ícone. Pede uma vez só.
- Sem comentários no código; um tipo por arquivo; constantes em `*Constants.swift`; textos em português; testes com Swift Testing.
- Arquivos novos de avisos ficam em `Financas/Reminders/`. Depois de criar arquivos ou mexer no `project.yml`, rodar `xcodegen generate`.
- Comando de teste: `xcodebuild test -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`.

## Review Focus

- Receita do mês seguinte dentro da janela (hoje 25/10, fixa no dia 1 de novembro) precisa gerar "hoje" e atraso. Teste em Task 2 (`dueItemsIncludeNextMonth`).
- Snapshot ainda não carregado (abertura do app, logo depois do `reset()`) não pode apagar os avisos agendados. Teste em Task 2 (`dueItemsNilBeforeLoad`).
- Reagendar depois das 19h não agenda nada para hoje. Teste em Task 1 (`skipsPastSlots`).
- Permissão negada e depois liberada nos Ajustes: o próximo reagendamento agenda. Teste em Task 3 (`schedulesAfterPermissionGrantedInSettings`).
- Toque no aviso com o app travado só troca a aba depois do desbloqueio. Teste em Task 5 (`routeWaitsForUnlock`).

---

### Task 1: Planejador de avisos

**Files:**
- Create: `Financas/Reminders/DueItem.swift`, `DueItemKind.swift`, `Reminder.swift`, `ReminderRoute.swift`, `ReminderConstants.swift`, `ReminderText.swift`, `ReminderPlanner.swift`
- Modify: `Financas/Income/CalendarDay.swift` (adiciona `days(until:)`)
- Test: `FinancasTests/ReminderPlannerTests.swift`, `FinancasTests/YearMonthTests.swift` (caso de `days(until:)`)

**Interfaces:**
- Produces:
  - `enum DueItemKind: Hashable, Sendable { case income }`
  - `struct DueItem: Hashable, Sendable { let id: String; let kind: DueItemKind; let title: String; let amount: Decimal; let dueDate: CalendarDay }`
  - `enum ReminderRoute: String, Sendable { case overdue, incomes }`
  - `struct Reminder: Hashable, Sendable { let id: String; let day: CalendarDay; let hour: Int; let title: String; let body: String; let route: ReminderRoute }`
  - `enum ReminderConstants { morningHour = 8; eveningHour = 19; windowDays = 14; routeKey = "route"; refreshTaskID = "dev.aglv.financas.refresh"; refreshInterval: TimeInterval = 6 * 60 * 60; permissionAskedKey = "reminders.permissionAsked" }`
  - `enum ReminderText { static func overdue(_ items: [DueItem]) -> (title: String, body: String); static func dueToday(_ items: [DueItem]) -> (title: String, body: String) }`
  - `enum ReminderPlanner { static func plan(items: [DueItem], now: Date, calendar: Calendar) -> [Reminder] }`
  - `CalendarDay.days(until other: CalendarDay) -> Int`

- [ ] **Step 1: Write the failing tests**

Em `ReminderPlannerTests` use `calendar` gregoriano com `TimeZone(identifier: "America/Sao_Paulo")` e um helper `at(_ day: CalendarDay, _ hour: Int) -> Date`. Itens de exemplo: `salary = DueItem(id: "s", kind: .income, title: "Salário Acme", amount: 8000, dueDate: day(2026, 10, 5))` e outros com `dueDate` explícito.

```swift
@Test func dueDayThenOverdueFromNextDay() // dueDate 2026-12-07, now = at(2026-12-07, 6)
// ids contém "due-2026-12-07-08"; não contém "overdue-2026-12-07-08" nem "overdue-2026-12-07-19"; contém "overdue-2026-12-08-08" e "overdue-2026-12-08-19"
@Test func oneOffOnSundayIsDueThatDay() // dueDate 2026-10-18 (domingo), now = at(2026-10-17, 20): contém "due-2026-10-18-08", "overdue-2026-10-19-08"
@Test func overdueEveryDayOfWindow() // item vencido em 2026-10-05, now = at(2026-10-07, 6): 28 avisos overdue, de 2026-10-07 a 2026-10-20, rota .overdue
@Test func dueAndOverdueSameMorningAreSeparate() // um vencido e um com dueDate hoje: dois avisos com day hoje e hour 8, ids "overdue-…-08" e "due-…-08"; o "due" tem rota .incomes
@Test func skipsPastSlots() // now = at(hoje, 19) + 1 min: nenhum aviso com day == hoje
@Test func neverMoreThan42() // 5 itens vencidos + 1 item por dia nos 14 dias: plan.count <= 42
@Test func noItemsNoReminders()
@Test func singleOverdueText() // ReminderText.overdue([salary]) == ("Receita atrasada", "Salário Acme · \(IncomeFormat.currency(8000)), prevista para \(IncomeFormat.shortDate(day(2026,10,5))).")
@Test func manyOverdueText() // 3 itens somando 12480: ("3 receitas atrasadas", "\(IncomeFormat.currency(12480)) ainda não recebidos.")
@Test func singleDueTodayText() // ("Receita prevista para hoje", "Salário Acme · \(IncomeFormat.currency(8000))")
@Test func manyDueTodayText() // 2 itens somando 11000: ("2 receitas previstas para hoje", "\(IncomeFormat.currency(11000)) no total.")
```

Em `YearMonthTests`: `day(2026, 9, 20).days(until: day(2026, 10, 8)) == 18` e `day(2026, 10, 8).days(until: day(2026, 10, 8)) == 0`.

- [ ] **Step 2: Run tests to verify they fail**

Run: o comando de teste. Expected: falha de compilação por tipos inexistentes.

- [ ] **Step 3: Implement**

`days(until:)` usa `Self.calendar.dateComponents([.day], from:to:)`. `ReminderPlanner.plan`: dia de hoje = `CalendarDay(date: now, calendar: calendar)`; para cada dia `D` de hoje até hoje + 13, atrasados = itens com `dueDate < D`, de hoje = itens com `dueDate == D`; gera `overdue` às 8h e às 19h se houver atrasados e `due` às 8h se houver de hoje. Descarta horário cuja data (`calendar.date(from: D, hour)`) seja `<= now`. O id usa `D.text` e a hora com dois dígitos.

- [ ] **Step 4: Run tests to verify they pass**

Run: o comando de teste. Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Financas/Reminders Financas/Income/CalendarDay.swift FinancasTests/ReminderPlannerTests.swift FinancasTests/YearMonthTests.swift Financas.xcodeproj
git commit -m "feat(avisos): calcula os avisos de receitas atrasadas e previstas para hoje"
```

### Task 2: Itens e atrasadas a partir do IncomeStore

**Files:**
- Modify: `Financas/Income/IncomeStore.swift`
- Create: `Financas/Reminders/DueItem+Occurrence.swift` (`extension DueItem { init(occurrence: IncomeOccurrence) }`)
- Test: `FinancasTests/IncomeStoreTests.swift`

**Interfaces:**
- Consumes: `DueItem` (Task 1).
- Produces:
  - `IncomeStore.overdueOccurrences: [IncomeOccurrence]` — atrasadas até hoje (meses anteriores e mês atual), ordenadas por `dueDate` e depois nome.
  - `IncomeStore.overdueTotal: Decimal`
  - `IncomeStore.dueItems: [DueItem]?` — `nil` quando `loadState != .loaded`; senão as ocorrências não recebidas de meses anteriores, do mês atual e do seguinte.
  - `DueItem(occurrence:)`: `id = occurrence.id`, `kind = .income`, `title = IncomeFormat.occurrenceTitle(occurrence)`, `amount = occurrence.expectedAmount`, `dueDate = occurrence.dueDate`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func overdueOccurrencesOrderedOldestFirst() // fixa sem recebimento em setembro e outubro (startMonth 2026-09), today 2026-10-16: overdue = [setembro, outubro]; overdueTotal = soma dos expectedAmount
@Test func overdueOccurrencesSkipReceived() // recebimento da fixa em outubro: só setembro
@Test func dueItemsNilBeforeLoad() // IncomeStore sem load(): dueItems == nil; depois de reset(): nil
@Test func dueItemsIncludeNextMonth() // today 2026-10-25, fixa dia 1: dueItems contém dueDate 2026-11-03 (próximo dia útil de 1/11, 2/11 feriado)
@Test func dueItemsUseBusinessDay() // today 2026-12-01, fixa dia 5 (sábado): dueDate 2026-12-07
@Test func dueItemsSkipReceived()
@Test func dueItemUsesOccurrenceTitleAndExpectedAmount() // por hora: title "Por hora · setembro"
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: falha de compilação.

- [ ] **Step 3: Implement** as propriedades acima reaproveitando `occurrences(in:)` e `IncomeSchedule.occurrences(in: today.yearMonth.next, ...)`.

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(receitas): expõe as atrasadas e os vencimentos para os avisos"
```

### Task 3: Agendador e central de notificações

**Files:**
- Create: `Financas/Reminders/ReminderAuthorization.swift`, `ReminderCenter.swift`, `SystemReminderCenter.swift`, `ReminderScheduler.swift`
- Modify: `FinancasTests/Fakes.swift` (adiciona `FakeReminderCenter`)
- Test: `FinancasTests/ReminderSchedulerTests.swift`

**Interfaces:**
- Consumes: `ReminderPlanner.plan`, `Reminder`, `DueItem`, `ReminderConstants` (Task 1).
- Produces:
  - `enum ReminderAuthorization: Sendable { case notDetermined, allowed, denied }`
  - `@MainActor protocol ReminderCenter { func authorization() async -> ReminderAuthorization; func requestAuthorization() async -> Bool; func replacePending(with reminders: [Reminder]) async; func removeDelivered() async; func removeAll() async }`
  - `@MainActor final class ReminderScheduler { init(center: ReminderCenter, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }, calendar: Calendar = .current); func requestPermissionIfNeeded(hasIncomes: Bool) async; func reschedule(items: [DueItem], clearingDelivered: Bool) async; func reset() async }`
  - `SystemReminderCenter: ReminderCenter` sobre `UNUserNotificationCenter.current()`: `replacePending` chama `removeAllPendingNotificationRequests` e adiciona um `UNNotificationRequest` por aviso, com `UNCalendarNotificationTrigger(dateMatching: [year, month, day, hour, minute: 0], repeats: false)`, `sound = .default` e `userInfo[ReminderConstants.routeKey] = route.rawValue`. `requestAuthorization` pede `[.alert, .sound]`. `authorization()` mapeia `.authorized`, `.provisional` e `.ephemeral` para `.allowed`.

- [ ] **Step 1: Write the failing tests** (defaults em `UserDefaults(suiteName: UUID().uuidString)!`)

```swift
@Test func asksOnceWhenThereAreIncomes() // requestPermissionIfNeeded(hasIncomes: true) duas vezes: center.requests == 1
@Test func doesNotAskWithoutIncomes() // hasIncomes: false: requests == 0; depois true: requests == 1
@Test func doesNotAskAgainAfterDenied() // status .denied, marca gravada: novo pedido não chama o center
@Test func reschedulesOnlyWhenAllowed() // status .notDetermined e .denied: pending vazio e replacePending não chamado
@Test func rescheduleReplacesPendingAndClearsDelivered() // allowed, clearingDelivered: true: pending == plan(...), deliveredRemoved == 1
@Test func backgroundRescheduleKeepsDelivered() // clearingDelivered: false: deliveredRemoved == 0
@Test func schedulesAfterPermissionGrantedInSettings() // .denied → reschedule nada; muda para .allowed → reschedule agenda
@Test func resetRemovesEverything() // reset(): removeAll chamado
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement** `ReminderScheduler`, `SystemReminderCenter` e o fake (grava `requests`, `pending`, `deliveredRemoved`, `removedAll`; `status` configurável).

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(avisos): agenda os avisos como notificações locais"
```

### Task 4: Aba Atrasadas

**Files:**
- Modify: `Financas/Home/AppTab.swift` (adiciona `overdue`), `Financas/Home/MainTabView.swift`
- Create: `Financas/Reminders/OverdueView.swift`, `Financas/Reminders/OverdueRow.swift`, `Financas/Reminders/OverdueTotalCard.swift`

**Interfaces:**
- Consumes: `IncomeStore.overdueOccurrences`, `overdueTotal` (Task 2); `CalendarDay.days(until:)` (Task 1); `ReceiptSheet`, `IncomeIcon`, `IncomeFormat`.
- Produces: `struct OverdueView: View` (sem parâmetros, lê `IncomeStore` do environment).

- [ ] **Step 1: Implement**

- `MainTabView`: terceira `Tab("Atrasadas", systemImage: "exclamationmark.circle", value: AppTab.overdue) { OverdueView() }` com `.badge(count)`, onde `count = incomeStore.overdueOccurrences.count` (badge 0 não aparece).
- `OverdueView`: `NavigationStack`, título "Atrasadas", `AppBackground`, `readableWidth`, `.refreshable { await store.load() }`, mesmos estados de carga da aba Receitas. Com itens: `OverdueTotalCard` ("Total atrasado", valor em `Theme.warning`, vidro), título de seção "Receitas" e a lista em vidro com `OverdueRow`, tocar abre `ReceiptSheet(occurrence:today:)`. Sem itens: card "Nada atrasado" com "Quando uma receita passar da data sem ser marcada como recebida, ela aparece aqui."
- `OverdueRow`: ícone e título como `OccurrenceRow`; legenda "\(IncomeFormat.shortDate(dueDate)) · \(n) dia(s)" com `n = dueDate.days(until: today)` ("1 dia", "n dias"); à direita o valor previsto e, quando `occurrence.month < today.yearMonth`, `OverdueBadge(text: IncomeFormat.monthName(occurrence.month))`.

- [ ] **Step 2: Build and run tests**

Run: o comando de teste. Expected: build ok e testes passando.

- [ ] **Step 3: Check on the simulator**

Abrir o app no iPhone 17 com uma receita atrasada: aba aparece com badge, lista, total, marcar como recebida tira a linha; sem atrasadas, estado vazio.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(avisos): adiciona a aba atrasadas"
```

### Task 5: Ligar avisos, toque e segundo plano

**Files:**
- Create: `Financas/Reminders/ReminderRouter.swift`, `Financas/AppDelegate.swift`, `Financas/Reminders/BackgroundRefresh.swift`
- Modify: `Financas/FinancasApp.swift`, `Financas/RootView.swift`, `Financas/Home/MainTabView.swift`, `project.yml`
- Test: `FinancasTests/ReminderRouterTests.swift`

**Interfaces:**
- Consumes: `ReminderScheduler` (Task 3), `IncomeStore.dueItems` (Task 2), `ReminderRoute`, `ReminderConstants` (Task 1), `AppTab.overdue` (Task 4).
- Produces:
  - `@MainActor @Observable final class ReminderRouter { private(set) var pendingRoute: ReminderRoute?; func receive(userInfo: [AnyHashable: Any]); func take(isUnlocked: Bool) -> ReminderRoute? }` — `take` devolve `nil` e mantém a rota enquanto travado; desbloqueado, devolve e limpa.
  - `final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` com `let router = ReminderRouter()`; em `didFinishLaunching` define `UNUserNotificationCenter.current().delegate = self`; `willPresent` devolve `[.banner, .list, .sound]`; `didReceive` chama `router.receive(userInfo:)`.
  - `enum BackgroundRefresh { static func schedule() }` — submete `BGAppRefreshTaskRequest(identifier: ReminderConstants.refreshTaskID)` com `earliestBeginDate = now + refreshInterval`, ignorando erro.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func routeWaitsForUnlock() // receive(["route": "overdue"]); take(isUnlocked: false) == nil; take(isUnlocked: true) == .overdue; take(isUnlocked: true) == nil
@Test func ignoresUnknownRoute() // receive(["route": "x"]): pendingRoute == nil
@Test func incomesRoute() // receive(["route": "incomes"]): take(isUnlocked: true) == .incomes
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement the wiring**

- `FinancasApp`: `@UIApplicationDelegateAdaptor(AppDelegate.self)`; cria `ReminderScheduler(center: SystemReminderCenter())` e põe no environment junto com `appDelegate.router`; `onSignedOut` também chama `Task { await reminders.reset() }`. Na cena: `.backgroundTask(.appRefresh(ReminderConstants.refreshTaskID)) { BackgroundRefresh.schedule(); await incomeStore.refresh(); if let items = await incomeStore.dueItems { await reminders.reschedule(items: items, clearingDelivered: false) } }`.
- `RootView`: função `syncReminders()` — `guard let items = incomeStore.dueItems`; se `lockManager.isUnlocked`, `await reminders.requestPermissionIfNeeded(hasIncomes: !incomeStore.snapshot.incomes.isEmpty)`; depois `await reminders.reschedule(items: items, clearingDelivered: true)`. Chamar depois do `refresh()` no `.task(id: lockManager.isUnlocked)`, em `.onChange(of: incomeStore.snapshot)` e em `.onChange(of: incomeStore.today)`. Em `.background` do `scenePhase`, chamar `BackgroundRefresh.schedule()`.
- `MainTabView`: com `.onChange(of: router.pendingRoute)` e `.onChange(of: lockManager.isUnlocked)`, aplica `router.take(isUnlocked:)`: `.overdue` → `selectedTab = .overdue`; `.incomes` → `incomeStore.showCurrentMonth()` e `selectedTab = .incomes`.
- `project.yml`, em `info.properties`: `UIBackgroundModes: [fetch]` e `BGTaskSchedulerPermittedIdentifiers: [dev.aglv.financas.refresh]`. Rodar `xcodegen generate`.

- [ ] **Step 4: Run tests to verify they pass**

Run: o comando de teste. Expected: todos passam (suite inteira).

- [ ] **Step 5: Manual check**

No iPhone e no simulador, seguindo "Como validar" da spec: permissão pedida no desbloqueio; com receita atrasada, adiantar o relógio para 8h e 19h e ver o aviso; tocar com o app travado, desbloquear e cair em Atrasadas; aviso "hoje" abre Receitas no mês atual; marcar como recebida limpa os avisos da Central; sair da conta limpa tudo.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(avisos): agenda os avisos no app e abre a aba certa ao tocar"
```
