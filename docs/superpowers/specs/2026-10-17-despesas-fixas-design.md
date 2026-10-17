# Despesas fixas

Data: 2026-10-17

## Por quê

O app já mostra o que falta receber no mês, mas não o que falta pagar. O dono quer cadastrar uma vez
as contas que se repetem todo mês (internet, condomínio, água, luz), ver quanto falta pagar, ser
avisado no dia do vencimento e marcar cada conta como paga. Com isso, o saldo do mês na home passa a
ser o que entrou menos o que saiu.

Internet e condomínio costumam ter o mesmo valor todo mês. Água e luz mudam com o consumo. O dono
trabalha com um valor estimado e ajusta mês a mês: quando a conta chega, lança o valor real; quando
paga, confirma o pagamento. Depois de três meses pagos, o estimado passa a ser a média dos últimos
meses.

## Objetivo

- Cadastrar despesas fixas mensais: nome, valor estimado, dia de vencimento, mês de início, mês de
  fim opcional.
- Para cada mês, o app gera a ocorrência de cada despesa, com vencimento e valor estimado.
- Lançar a conta do mês antes de pagar, com o valor real e, se preciso, outro vencimento.
- Marcar como paga, com data e valor pagos.
- Estimado pela média dos 3 últimos pagamentos quando houver pelo menos 3 meses pagos.
- Aba Despesas, no formato da aba Receitas.
- Home com "Falta pagar" ao lado de "Falta receber", e saldo e lançamentos com os pagamentos.
- Avisos no dia do vencimento, de manhã e à noite, e avisos de atraso até a conta ser paga.
- Seção Despesas na aba Atrasadas.
- Tirar os ícones das linhas de receitas e despesas em todo o app.

## Fora do escopo

- Despesas avulsas e despesas parceladas. Esta entrega cobre só as fixas mensais.
- Categorias, ícones ou cores por despesa.
- Marcar como paga sozinha (débito automático). Toda conta é confirmada na mão.
- Regra "Dia não útil" configurável para despesas. A configuração existente continua valendo só para
  receitas.
- Horários de aviso próprios para despesas. Usam os horários da tela de Configurações.
- Pagar pela notificação.
- Uso offline. Segue o comportamento das receitas: sem internet, a aba mostra o erro e "Tentar de
  novo".
- Importar extrato ou boleto.

## Anti-objetivos

- O dono não pode ter que cadastrar a mesma conta todo mês.
- Mudar o estimado ou o dia de vencimento não pode alterar meses anteriores.
- Lançar ou pagar não pode exigir digitação no caso normal: tudo vem preenchido.
- Parar de avisar uma conta que ainda não foi marcada como paga.
- Os dados de uma conta não podem ser lidos por outra. Toda tabela nova tem RLS desde a primeira
  migration.

## Estado atual (para quem vai construir)

Ver também, nesta ordem:
`docs/superpowers/specs/2026-10-16-cadastro-de-receitas-design.md`,
`docs/superpowers/specs/2026-10-17-home-por-mes-e-avatar-design.md`,
`docs/superpowers/specs/2026-10-17-avisos-de-receitas-design.md` e
`docs/superpowers/specs/2026-10-17-configuracoes-da-conta-design.md`.

- `Financas/Income/`: modelo, cálculo e telas de receitas. `IncomeSchedule` calcula as ocorrências a
  partir do `IncomeSnapshot` e de `today`; `IncomeStore` tem `snapshot`, `selectedMonth`, `today`,
  `load()`, `refresh()`, `reset()`, `moveToday()`, `occurrences(in:)`, `overdueOccurrences`,
  `dueItems`, `summary(for:)`. `BusinessCalendar` tem os feriados nacionais e
  `businessDayOnOrAfter`. `IncomeFormat` formata moeda, data curta e nome do mês.
- `IncomeSnapshot` já carrega `AccountSettings`. `IncomeService.load()` busca tudo em paralelo no
  Supabase.
- Telas de receitas: `IncomesView`, `IncomeFormView`, `ReceiptSheet` (via `IncomeReceiptFlow`),
  `OccurrenceRow`, `RecurringIncomeRow`, `IncomeMonthSummaryCard`, `MonthPicker`, `OverdueBadge`,
  `EndedIncomesView`.
- Home: `HomeView` com saldo (`HomeMonthSummary`), `IncomeSummaryCard` e lançamentos do mês com
  `TransactionRow`. O mês da home é o `IncomeStore.selectedMonth`, o mesmo da aba Receitas.
- Abas: `MainTabView` e `AppTab` (`home`, `incomes`, `overdue`). Badge da aba Atrasadas com
  `incomeStore.overdueOccurrences.count`.
- Avisos (`Financas/Reminders/`): `DueItem` (id, `DueItemKind`, título, valor, `dueDate`),
  `DueItemKind` só com `income`, `ReminderPlanner.plan(items:settings:now:calendar:)`, `ReminderText`,
  `ReminderScheduler`, `ReminderRouter`/`ReminderRoute`, `OverdueView`, `OverdueRow`,
  `OverdueTotalCard`. Janela de 14 dias, limite de 64 avisos pendentes do iOS.
  `RootView.syncReminders()` e `FinancasApp.refreshReminders()` (segundo plano) reagendam.
- Ícones de linha: `IncomeIcon`, usado em `OccurrenceRow`, `RecurringIncomeRow`, `OverdueRow` e
  `TransactionRow`.
- Banco: migrations em `supabase/migrations/`. Tabelas `incomes`, `income_amounts` (vigência de valor
  por `valid_from`), `income_receipts` (uma por receita e mês), `account_settings`. RLS por
  `user_id = (select auth.uid())` em todas, com políticas que restringem os filhos ao dono do pai
  (`20261017000000_restrict_income_children_to_owner.sql`).

Convenções do dono: sem comentários no código; um tipo por arquivo; types e constantes em arquivos
próprios (`*Constants.swift`); textos da interface em português; testes com Swift Testing em
`FinancasTests`; projeto gerado pelo `project.yml`; o app não usa `alert`.

## Decisões

### Ocorrências calculadas, lançamentos e pagamentos gravados

Mesmo modelo das receitas. O banco guarda a despesa cadastrada, as vigências de estimado e dia, e o
que o dono registrou em cada mês (conta lançada, pagamento). Ocorrências sem registro são calculadas
no app para o mês na tela.

### Cadastro

- Campos: nome, valor estimado, dia de vencimento (1 a 31), mês de início (padrão: mês atual), mês de
  fim opcional.
- Dia 31 em mês mais curto usa o último dia do mês, como nas receitas.
- Editar o valor estimado ou o dia de vencimento vale do mês atual em diante. Meses anteriores
  continuam com o estimado e o dia que tinham. O formulário não pergunta "a partir de quando" (decisão
  de quem desenhou: o dono só falou em trocar o dia daqui para frente; nas receitas o mês da vigência
  é perguntado porque aumento de salário tem data).
- Encerrar define o mês de fim. Excluir apaga a despesa e tudo que foi registrado dela, com
  confirmação na própria tela. Igual às receitas.
- Sem tipo, ícone ou categoria.

### Vencimento

- Data da ocorrência do mês M: dia de vencimento vigente em M; se cair em sábado, domingo ou feriado
  nacional, o próximo dia útil (`BusinessCalendar.businessDayOnOrAfter`). Sempre essa regra, qualquer
  que seja a configuração "Dia não útil" das receitas.
- Ao lançar a conta, o dono pode trocar o vencimento só daquele mês. A data informada vale como está,
  sem regra de dia útil (é a data impressa na conta).
- O vencimento pode cair no mês seguinte por causa do dia útil (dia 31 num sábado). A ocorrência
  continua sendo do mês M, como nas receitas.

### Valor estimado

Para a ocorrência do mês M sem conta lançada e sem pagamento:

- Se a despesa tem pelo menos 3 meses pagos antes de M, contando só os meses a partir da última vez
  que o dono editou o valor estimado: média dos valores pagos dos 3 meses pagos mais recentes antes de
  M, arredondada para centavos.
- Senão: o valor estimado vigente em M.

Editar o valor estimado reinicia a contagem: até juntar 3 meses pagos depois da edição, vale o valor
digitado. Assim, quando o condomínio sobe, o dono corrige o estimado e a média antiga não puxa o
valor para baixo. (Decisão de quem desenhou.) Editar só o dia de vencimento não reinicia.

"Depois da edição" quer dizer meses posteriores ao mês em que a nova vigência começa. O próprio mês da
edição fica fora da média, porque pode já ter sido pago com o valor antigo. Custa um mês a mais para a
média voltar a valer, e não exige gravar o momento da edição. (Decisão de quem desenhou.)

A vigência criada por uma edição começa no maior entre o mês atual e o mês de início da despesa. Para
uma despesa que ainda não começou, editar o estimado substitui a vigência inicial. (Decisão de quem
desenhou.)

Exemplo: luz cadastrada em julho com estimado R$ 180,00. Pagou julho R$ 196,40, agosto R$ 201,10 e
setembro R$ 219,80. Outubro e os meses seguintes, sem conta lançada, mostram R$ 205,77.

A linha da despesa cadastrada mostra o valor que vale para o mês atual e de onde ele vem: "média de 3
meses" ou "estimado".

### Valor da ocorrência

- Paga: valor pago.
- Com conta lançada: valor da conta.
- Sem nada: estimado do mês (regra acima).

### Status

- **Paga**: tem pagamento.
- **Atrasada**: sem pagamento e vencimento anterior a hoje.
- **Pendente**: sem pagamento e vencimento hoje ou depois.

Além do status, a ocorrência sem pagamento mostra se o valor é estimado ou se a conta já foi lançada.
O selo da linha segue a ordem: "atrasada", senão "conta lançada", senão "estimada".

Atrasadas de meses anteriores continuam aparecendo no mês atual até serem pagas, com o mês de
referência na linha ("Luz · setembro"). Mesma regra das receitas.

### Lançar conta e marcar como paga

Tocar numa ocorrência abre uma sheet com o título "\(nome) · \(mês)", o vencimento e o valor da
ocorrência em destaque com a origem ("estimado pela média de jul, ago e set", "estimado" ou "conta
lançada"). Um seletor no topo alterna entre dois modos. Abre em "Lançar conta" quando não há conta
lançada e em "Marcar como paga" quando já há. (Validado com o dono em mockup.)

- **Lançar conta**: valor da conta (padrão: o valor da ocorrência) e vencimento (padrão: o vencimento
  calculado). Botão "Salvar conta".
- **Marcar como paga**: valor pago (padrão: o valor da conta lançada ou, sem ela, o estimado) e data
  do pagamento (padrão: hoje, só até hoje). Botão "Marcar como paga". Pagar sem ter lançado a conta é
  permitido.
- O valor pago pode ser diferente do lançado sem justificativa. Para a média, vale o pago.
- Conta lançada pode ser editada ou removida (volta ao estimado). Pagamento pode ser editado ou
  desmarcado (volta a pendente ou atrasada, mantendo a conta lançada se houver).

### Aba Despesas

Nova aba entre Receitas e Atrasadas, título "Despesas", ícone `arrow.up.circle` (decisão de quem
desenhou, espelhando o `arrow.down.circle` de Receitas). Mesmo layout da aba Receitas:

- `MonthPicker` ligado ao mesmo mês da home e da aba Receitas (um mês só no app).
- Card de resumo: Pago, Falta pagar, Previsto.
  - Pago: soma dos pagamentos das ocorrências do mês.
  - Falta pagar: soma dos valores das ocorrências sem pagamento. No mês atual, inclui as atrasadas de
    meses anteriores.
  - Previsto: pago + falta pagar.
- Seção "A pagar": atrasadas primeiro (atrasadas de meses anteriores antes das do mês), depois por
  vencimento.
- Seção "Pagas": data do pagamento na legenda.
- Seção "Cadastradas" (mês atual e futuros), com link para "Encerradas", como nas receitas.
- Botão "+" na toolbar abre o cadastro. Estado vazio com convite para cadastrar a primeira conta.
- Pull to refresh recarrega.

Mês passado no seletor mostra só as ocorrências daquele mês, com o status de hoje. Mês futuro mostra
só as daquele mês.

### Home

Validado com o dono em mockup (opção B).

- O `IncomeSummaryCard` vira um card dividido ao meio. Esquerda: "Falta receber", como hoje. Direita:
  "Falta pagar", com valor, barra de progresso (pago sobre previsto), próxima conta pendente ("Água ·
  19 out") e selo com a quantidade de atrasadas.
- Tocar em cada metade abre a aba correspondente no mês da home.
- Sem despesa cadastrada, a metade direita mostra um convite curto ("Cadastre suas contas fixas").
  Idem para a metade esquerda sem receita. (Decisão de quem desenhou.)
- Saldo do mês: recebimentos com data no mês menos pagamentos com data no mês. O gráfico desce nos
  dias com pagamento.
- Lançamentos do mês: recebimentos e pagamentos juntos, do mais recente para o mais antigo. Pagamento
  com legenda "Despesa · \(dia)" e valor com "−" na cor primária; recebimento como hoje, "+" em
  `Theme.positive`.

### Sem ícones

As linhas deixam de ter o círculo com ícone, em receitas e em despesas: `OccurrenceRow`,
`RecurringIncomeRow`, `OverdueRow`, `TransactionRow` e as linhas novas de despesa. `IncomeIcon` sai
do projeto se ficar sem uso. O estado continua visível pela cor do valor (verde em recebida), pelo
"+"/"−" e pelos selos. (Pedido do dono.)

### Aba Atrasadas

- Ganha a seção "Despesas", abaixo de "Receitas", com as despesas atrasadas da mais antiga para a mais
  nova e depois pelo nome. Legenda "\(vencimento) · \(n) dias". Tocar abre a sheet da despesa, já em
  "Marcar como paga".
- O card de topo passa a mostrar duas linhas, "A receber" e "A pagar", em vez de um total só, porque
  somar as duas coisas não diz nada. (Decisão de quem desenhou.) Cada linha só aparece quando tem
  valor.
- Badge da aba: receitas atrasadas + despesas atrasadas.
- Seção sem itens não aparece. Estado vazio "Nada atrasado" só quando as duas estão vazias.

### Avisos

Mesma estrutura dos avisos de receitas: notificações locais, janela de 14 dias, reagendamento nos
mesmos momentos (load, refresh, salvar, segundo plano), limpeza ao sair da conta. Agora também
reagenda quando o dono salva, lança, paga ou desmarca uma despesa.

- **Vence hoje**: no dia do vencimento de uma despesa sem pagamento, um aviso no horário "Prevista
  para hoje" e outro no horário "Atrasadas à noite" da tela de Configurações, cada um respeitando o
  seu liga/desliga. (Pedido do dono: começo e fim do dia. Reaproveitar os horários: decisão de quem
  desenhou.)
- **Atrasada**: as despesas atrasadas entram nos avisos de atraso de manhã e de noite que já existem,
  todos os dias até serem pagas.
- Um aviso por horário e por situação, juntando receitas e despesas, para caber no limite do iOS. No
  máximo 4 avisos por dia (atraso manhã, atraso noite, vence hoje manhã, vence hoje noite), 56 em 14
  dias. (Decisão de quem desenhou.)
- O aviso de "vence hoje" da noite só fala de despesas. O de manhã junta receitas previstas e
  despesas que vencem.
- Valor usado no texto: o valor da ocorrência (conta lançada ou estimado).

Textos (decisão de quem desenhou; quem constrói pode ajustar mantendo o formato):

| Caso | Título | Corpo |
| --- | --- | --- |
| 1 despesa vence hoje | Conta vence hoje | Luz · R$ 212,30 |
| N despesas vencem hoje | 2 contas vencem hoje | R$ 306,40 no total. |
| 1 despesa atrasada | Conta atrasada | Luz · R$ 212,30, venceu em ter, 13 out. |
| N despesas atrasadas | 2 contas atrasadas | R$ 306,40 ainda não pagos. |
| Receitas e despesas hoje | Hoje: 1 receita e 2 contas | R$ 13.020,04 a receber e R$ 306,40 a pagar. |
| Receitas e despesas atrasadas | Atrasadas: 1 receita e 2 contas | R$ 15.120,00 a receber e R$ 306,40 a pagar. |

Só receitas: textos de hoje, sem mudança.

Ao tocar: atraso abre a aba Atrasadas. "Vence hoje" abre a aba Despesas no mês atual; se o aviso tiver
só receitas, abre a aba Receitas como hoje.

O `DueItemKind` ganha `expense`. O pedido de permissão de notificação passa a acontecer também quando
existe ao menos uma despesa cadastrada.

### Banco

Tabelas novas no Supabase, com RLS igual às de receitas (select, insert, update e delete só do
próprio `user_id`, e filhos só de despesa do próprio dono). Uma linha de registro por despesa e mês.
O que precisa caber:

- despesa: nome, mês de início, mês de fim;
- vigências: valor estimado e dia de vencimento, cada um com o mês a partir do qual vale, para que
  editar um não mude meses anteriores e para saber desde quando contar a média;
- registro do mês: conta lançada (valor, vencimento informado), pagamento (data, valor). Os dois
  podem existir separados.

### Arquitetura

- Cálculo puro e testável para despesas, no molde do `IncomeSchedule`: ocorrências, estimado pela
  média, status, resumo do mês, atrasadas de meses anteriores.
- Store e serviço próprios de despesas, no molde de `IncomeStore` e `IncomeService`, com fake nos
  testes. O mês selecionado e o "hoje" ficam num lugar só, compartilhado entre home, Receitas e
  Despesas.
- O carregamento em segundo plano (`FinancasApp.refreshReminders()`) carrega receitas e despesas antes
  de reagendar, para os avisos de segundo plano incluírem as duas.
- `HomeMonthSummary` passa a receber os pagamentos.

## Como validar

- Testes do cálculo de despesas:
  - vencimento em dia útil, em sábado, em feriado; dia 31 em fevereiro;
  - vencimento informado ao lançar substitui o calculado só naquele mês;
  - estimado com 0, 2 e 3 meses pagos; média dos 3 mais recentes com 5 meses pagos; arredondamento;
  - editar o estimado reinicia a contagem, e o mês da edição não entra na média; editar o dia não
    reinicia;
  - editar o estimado de despesa com início futuro substitui a vigência inicial;
  - editar estimado ou dia não muda meses anteriores;
  - valor da ocorrência: pago, depois lançado, depois estimado;
  - status e selo; atrasada de mês anterior aparece no mês atual e some ao pagar;
  - resumo Pago / Falta pagar / Previsto, com e sem atrasadas antigas.
- Testes do `HomeMonthSummary`: saldo com recebimentos e pagamentos; pagamento conta no mês da data do
  pagamento; lançamentos misturados e ordenados.
- Testes do `ReminderPlanner`: despesa vencendo hoje gera aviso nos dois horários; liga/desliga de
  cada horário; receita e despesa no mesmo horário viram um aviso com o texto combinado; despesa paga
  não gera aviso; no máximo 56 avisos em 14 dias; destino do toque.
- Testes do store com fake: lançar, pagar, editar, desmarcar, encerrar, excluir; erro de rede mantém o
  estado anterior e mostra a mensagem.
- Migration aplicada no Supabase: outro usuário não lê nem altera despesas, vigências e registros;
  advisors sem aviso.
- Manual no iPhone: cadastrar luz e internet, lançar a conta da luz, pagar a internet, conferir a aba,
  a home e a aba Atrasadas; adiantar o relógio para o dia do vencimento e ver os avisos de manhã e de
  noite; pagar e ver os avisos sumirem; abrir no iPad e ver os mesmos dados.

## Deixado para quem constrói

- Nomes de tipos, arquivos, tabelas e migration, seguindo o padrão do projeto.
- Esquema exato das tabelas, desde que cubra o que está em "Banco".
- Se o mês selecionado e o "hoje" saem do `IncomeStore` para um tipo próprio ou ficam lá com o store de
  despesas lendo dele.
- Layout fino da aba Despesas, da sheet e do card dividido da home.
- Textos de ajuda do formulário e dos estados vazios.
