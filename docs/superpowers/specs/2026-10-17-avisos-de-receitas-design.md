# Avisos de receitas atrasadas e previstas para hoje

Data: 2026-10-17

## Por quê

O app marca como atrasada a receita sem recebimento cuja data prevista já passou, mas o dono só
descobre isso se abrir a home ou a aba Receitas. Ele quer que o app avise, todo dia, até a receita ser
marcada como recebida, e também avise de manhã quando uma receita deve cair naquele dia.

Com várias receitas, a seção "Pendentes" da aba Receitas mistura atrasadas e pendentes do mês. O dono
quer uma lista separada só com as atrasadas. Mais para frente a mesma lógica vai valer para despesas.

## Objetivo

- Aviso de atraso às 8h e às 19h, todos os dias (inclusive fim de semana e feriado), enquanto houver
  receita atrasada.
- Aviso às 8h no dia em que uma ou mais receitas devem cair.
- Aba nova "Atrasadas" com todas as receitas atrasadas, aberta ao tocar no aviso de atraso.

## Fora do escopo

- Despesas. A lista e os avisos ficam prontos para receber outro tipo de lançamento, mas despesas
  entram em outra entrega.
- Escolher os horários. Ficam fixos em 8h e 19h por enquanto.
- Aviso antes do vencimento (véspera, semana).
- Um aviso por receita. É sempre um aviso por horário, resumindo todas.
- Marcar como recebida pela própria notificação.
- Push enviado pelo servidor. A conta de desenvolvedor da Apple é gratuita (Personal Team) e não tem
  a capability de Push Notifications.

## Anti-objetivos

- Avisar de receita já marcada como recebida no próprio aparelho.
- Continuar avisando depois de sair da conta.
- Insistir em pedir permissão de notificação se o dono negar.

## Estado atual (para quem vai construir)

Ver também `docs/superpowers/specs/2026-10-16-cadastro-de-receitas-design.md` e
`docs/superpowers/specs/2026-10-17-home-por-mes-e-avatar-design.md`.

- `Financas/Income/IncomeSchedule.swift`: calcula as ocorrências a partir do `IncomeSnapshot` e de
  `today`. Fixa e por hora caem em `BusinessCalendar.businessDayOnOrAfter(dia escolhido)`; avulsa cai
  na data informada. Status: recebida (tem recebimento), atrasada (`dueDate < today`), pendente.
  `overdue(before:)` traz as atrasadas de meses anteriores.
- `Financas/Income/IncomeStore.swift`: `snapshot`, `today`, `refresh()` a cada desbloqueio e na virada
  do dia, `markReceived`, `unmarkReceived`, `save`, `end`, `delete`, `reset()` ao sair da conta.
  `occurrences(in:)` no mês atual já inclui as atrasadas de meses anteriores.
- `Financas/Home/MainTabView.swift` e `AppTab.swift`: abas Início e Receitas.
- `Financas/Income/OccurrenceRow.swift`, `OverdueBadge.swift`, `ReceiptSheet.swift`: linha da
  ocorrência, selo "atrasada" e folha de marcar como recebida.
- `Financas/RootView.swift`: trava (PIN/Face ID) e `PrivacyCoverView`. `FinancasApp.swift` monta os
  stores e o `onSignedOut`.
- O app não usa notificações nem tarefas em segundo plano hoje. O projeto é gerado pelo `project.yml`.

Convenções do dono: sem comentários no código; um tipo por arquivo; constantes em `*Constants.swift`;
textos em português; testes com Swift Testing.

## Decisões

### Quando avisa

- **Atrasadas**: às 8h e às 19h de cada dia em que existir ao menos uma ocorrência sem recebimento com
  `dueDate` anterior ao dia. Vale para todos os dias da semana. Atrasadas de meses anteriores entram.
- **Previstas para hoje**: às 8h do dia em que existir ao menos uma ocorrência sem recebimento com
  `dueDate` igual ao dia. Só de manhã.
- Num dia com as duas situações, às 8h chegam dois avisos separados (pedido do dono).
- A data prevista segue a regra de dia útil que já existe. Exemplo: receita fixa no dia 5, que cai num
  sábado, tem `dueDate` na segunda dia 7. O aviso "hoje" sai no dia 7 às 8h, e o de atraso começa no
  dia 8 às 8h.
- Horário e calendário do aparelho, como o resto do app.

### Texto

Mostra nomes e valores, inclusive na tela bloqueada (o dono aceitou). Valores com
`IncomeFormat.currency`, datas com `IncomeFormat.shortDate`. Para receita por hora, o valor é o
previsto calculado.

| Caso | Título | Corpo |
| --- | --- | --- |
| 1 atrasada | Receita atrasada | Salário Acme · R$ 8.000,00, prevista para qua, 7 out. |
| N atrasadas | 3 receitas atrasadas | R$ 12.480,00 ainda não recebidos. |
| 1 prevista hoje | Receita prevista para hoje | Salário Acme · R$ 8.000,00 |
| N previstas hoje | 2 receitas previstas para hoje | R$ 11.000,00 no total. |

O nome da receita usa `IncomeFormat.occurrenceTitle`. (Textos: decisão de quem desenhou.) A
notificação mostra o ícone do app, que é o padrão do iOS.

### Ao tocar

- Aviso de atraso: abre a aba Atrasadas.
- Aviso de hoje: abre a aba Receitas no mês atual. (Decisão de quem desenhou.)
- Se o app estiver travado, o desbloqueio vem primeiro e a aba abre em seguida.
- Com o app aberto na hora do aviso, ele aparece como banner normalmente. (Decisão de quem desenhou.)

### Aba Atrasadas

- Terceira aba, depois de Início e Receitas. Título "Atrasadas", ícone `exclamationmark.circle`
  (decisão de quem desenhou). A aba mostra a quantidade de atrasadas como badge; sem atrasadas, sem
  badge.
- Topo: card "Total atrasado" com a soma dos valores previstos, em `Theme.warning`.
- Seção "Receitas": todas as atrasadas, da data prevista mais antiga para a mais nova, depois pelo
  nome. Cada linha segue o `OccurrenceRow`, com a legenda "\(data prevista) · \(n) dias" (dias desde a
  data prevista) e, para ocorrência de mês anterior, o nome do mês ao lado do valor.
- Tocar numa linha abre o `ReceiptSheet`. Ao salvar, a linha sai da lista.
- Sem atrasadas: estado vazio "Nada atrasado" com uma frase curta. A aba continua visível.
  (Decisão de quem desenhou.)
- Não tem seletor de mês: é sempre "até hoje".
- Pull to refresh chama `incomeStore.load()`, como na aba Receitas.
- A seção de despesas não aparece nesta entrega.

### Como os avisos são agendados

Notificações locais (`UNUserNotificationCenter`) agendadas por cada aparelho. iPhone e iPad avisam ao
mesmo tempo.

- O app calcula os avisos dos próximos 14 dias a partir do snapshot atual, supondo que nada novo seja
  recebido. Para cada dia, o conteúdo das 8h e das 19h é exato para esse snapshot. Isso dá no máximo
  42 avisos pendentes, abaixo do limite de 64 do iOS. (Janela de 14 dias: decisão de quem desenhou.)
- Cada aviso tem identificador fixo por dia e horário (por exemplo `overdue-2026-10-08-08`,
  `due-2026-10-07-08`). Reagendar remove todos os pendentes e todos os já entregues do app (a
  Central de Notificações fica limpa) e agenda a lista nova. Um aviso entregue não pode ter o texto
  atualizado, e o dono está com o app aberto quando o reagendamento roda, então não perde nada. A
  exceção é a tarefa em segundo plano: ela troca só os pendentes e deixa os entregues, porque o dono
  ainda não viu. (Decisão de quem desenhou.)
- Reagenda quando:
  - o `IncomeStore` termina `load()` ou `refresh()` com sucesso;
  - `markReceived`, `unmarkReceived`, `save`, `end` ou `delete` dão certo;
  - o iOS roda a tarefa de atualização em segundo plano (`BGAppRefreshTask`), que carrega o snapshot
    do Supabase e reagenda. Pede a próxima execução para dali a umas 6 horas; o iOS decide quando roda
    de fato. Sem internet, a tarefa termina sem mexer no que está agendado.
- Sair da conta remove os avisos pendentes e os já entregues.
- Limite aceito: se o dono marcar como recebida no iPad, o iPhone pode dar avisos desatualizados até
  abrir o app ou rodar a atualização em segundo plano. Se o app ficar mais de 14 dias sem abrir e sem
  rodar em segundo plano, os avisos param até a próxima abertura.

### Permissão

- O app pede permissão (alerta, som, sem badge no ícone) uma vez só, no primeiro momento em que o
  app está desbloqueado com o snapshot carregado e ao menos uma receita cadastrada. Na prática: logo
  depois do `refresh()` do desbloqueio, para quem já tem receitas, ou logo depois de salvar a primeira
  receita. O pedido espera o snapshot carregar. A marca guardada é "já pedi". (Decisão de quem
  desenhou.)
- Se a permissão ainda não foi decidida (`notDetermined`), o reagendamento não agenda nada.
- Negada: não pede de novo e não mostra aviso na tela. A aba Atrasadas funciona igual. Se o dono
  liberar depois nos Ajustes do iOS, o próximo reagendamento já agenda.

### Preparado para despesas

O cálculo dos avisos recebe uma lista de itens com vencimento (nome, valor, data prevista, tipo), não
`IncomeOccurrence`. Hoje só as receitas viram itens. Quando as despesas existirem, viram itens do
mesmo jeito e os textos ganham as variantes de despesa. A aba Atrasadas já é organizada em seções por
tipo, com só "Receitas" por enquanto.

### Arquitetura

- Planejador puro e testável: a partir dos itens, de hoje e da janela de dias, devolve a lista de
  avisos (identificador, dia, horário, título, corpo, destino). Sem dependência de `UserNotifications`.
- Um agendador que fala com `UNUserNotificationCenter` por um protocolo, com fake nos testes, como
  `IncomeService`. Pede permissão, remove e agenda.
- O destino do toque chega pelo delegate do `UNUserNotificationCenter` e fica guardado até o app estar
  desbloqueado; o `MainTabView` troca a aba a partir dele. `AppTab` ganha `overdue`.
- `project.yml` ganha o Background Mode `fetch` e o identificador da tarefa em
  `BGTaskSchedulerPermittedIdentifiers`.

## Como validar

- Testes do planejador:
  - receita fixa no dia 5 que cai num sábado: "hoje" na segunda às 8h, atraso a partir de terça às 8h
    e 19h;
  - avulsa num domingo: "hoje" no domingo, atraso a partir de segunda;
  - recebida não gera aviso; atrasada de mês anterior entra no total;
  - 1 e N itens geram os textos da tabela;
  - dia com atrasada e prevista gera dois avisos às 8h;
  - janela de 14 dias e no máximo 42 avisos;
  - aviso de hoje às 8h não sai se já passou das 8h no momento do agendamento (idem 19h).
- Testes do agendador com fake: reagendar remove pendentes e entregues e agenda os novos; sair da
  conta limpa; permissão negada não agenda e não pede de novo; pedido só sai com receita cadastrada e
  snapshot carregado.
- Teste da aba Atrasadas pelo cálculo da lista: ordem, total, dias de atraso.
- Manual no iPhone: com uma receita atrasada, adiantar o relógio do aparelho para 8h e 19h e ver os
  avisos; tocar no aviso com o app travado, desbloquear e cair na aba Atrasadas; marcar como recebida
  e ver os avisos sumirem; repetir no iPad.

## Deixado para quem constrói

- Layout fino da aba Atrasadas e do estado vazio.
- Nomes de tipos, arquivos e do identificador da tarefa em segundo plano, seguindo o padrão do
  projeto.
- Onde guardar a marca de "permissão já pedida".
