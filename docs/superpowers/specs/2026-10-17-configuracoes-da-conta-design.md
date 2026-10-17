# Configurações da conta

Data: 2026-10-17

## Por quê

Três regras estão fixas no código e o dono quer ajustá-las sem nova versão do app:

- quais tipos de receita aparecem no cadastro (hoje sempre Fixa, Por hora e Avulsa);
- o que acontece quando o dia de recebimento cai em fim de semana ou feriado (hoje sempre passa para
  o próximo dia útil);
- os horários dos avisos (hoje atrasadas às 8h e às 19h, prevista para hoje às 8h).

As configurações são da conta, não do aparelho: iPhone e iPad mostram e usam os mesmos valores.

## Objetivo

Uma tela "Configurações", aberta pelo menu do avatar, com três seções:

1. **Tipos de receita**: Fixa, Por hora e Avulsa, cada um ligado ou desligado.
2. **Dia não útil**: próximo dia útil, dia útil anterior ou manter a data.
3. **Avisos**: atrasadas de manhã, atrasadas à noite e prevista para hoje, cada um com liga/desliga e
   horário.

Os padrões são o comportamento atual. Quem nunca abrir a tela não percebe diferença.

## Fora do escopo

- Tipos de receita criados pelo dono (nome, ícone, cor). Os tipos continuam sendo os três de hoje.
- Regra de dia não útil por receita. É uma regra só para a conta.
- Feriados estaduais, municipais ou cadastrados pelo dono. O calendário continua com os feriados
  nacionais de `IncomeConstants`.
- Mais de três avisos por dia ou avisos antes do vencimento (véspera, semana).
- Configurações por aparelho.
- Cache offline das configurações. O app já não guarda as receitas fora do Supabase; as
  configurações seguem o mesmo caminho.

## Anti-objetivos

- Esconder ou parar de avisar receitas já cadastradas de um tipo que foi desligado.
- Mudar o cálculo do valor de receita Por hora. Ele continua usando os dias úteis do mês anterior,
  qualquer que seja a regra de dia não útil.
- Deixar avisos agendados com o horário antigo depois que o dono mudou e salvou.
- Conta sem nenhum tipo de receita ligado.

## Estado atual (para quem vai construir)

Ver também `docs/superpowers/specs/2026-10-16-cadastro-de-receitas-design.md` e
`docs/superpowers/specs/2026-10-17-avisos-de-receitas-design.md`.

- `Financas/Income/IncomeKind.swift`: `fixed`, `hourly`, `oneOff` (`one_off` no banco).
  `IncomeKindStyle.swift` tem título, ícone e cor de cada um.
- `Financas/Income/IncomeFormConstants.swift`: `kinds` alimenta o `Picker("Tipo")` de
  `IncomeFormView.swift`. O texto de ajuda do formulário cita "cai no próximo dia útil", e
  `IncomeFormat.swift` mostra "\(dia) · próximo dia útil" na linha da receita cadastrada.
- `Financas/Income/IncomeSchedule.swift`: Fixa e Por hora usam
  `BusinessCalendar.businessDayOnOrAfter(month.day(day))` para o `dueDate`. Avulsa usa a data
  informada, sem regra de dia útil.
- `Financas/Income/IncomeStore.swift`: `snapshot`, `load()`, `refresh()`, `occurrences(in:)`,
  `overdueOccurrences`, `dueItems` (mês anterior, atual e seguinte).
- `Financas/Income/SupabaseIncomeService.swift`: `load()` busca `incomes`, `income_amounts` e
  `income_receipts` em paralelo e monta o `IncomeSnapshot`.
- `Financas/Reminders/ReminderPlanner.swift`: usa `ReminderConstants.morningHour` e `eveningHour`.
  `Reminder` tem só `hour`. Os ids são `overdue-AAAA-MM-DD-HH` e `due-AAAA-MM-DD-HH`.
- `Financas/RootView.swift`: `syncReminders()` reagenda quando o snapshot muda, na volta ao primeiro
  plano e na virada do dia. `FinancasApp.refreshReminders()` faz o mesmo em segundo plano.
- `Financas/Home/HomeView.swift`: menu do avatar com Escolher foto, Remover foto, Bloquear e Sair da
  conta.
- Banco: migrations em `supabase/migrations/`, RLS por `user_id = auth.uid()` em todas as tabelas.

Convenções do dono: sem comentários no código; um tipo por arquivo; types e constantes em arquivos
próprios (`*Constants.swift`); textos em português; testes com Swift Testing; projeto gerado pelo
`project.yml`.

## Decisões

### Onde ficam salvas

Tabela nova `account_settings`, uma linha por usuário, com RLS igual às outras tabelas (select,
insert e update só do próprio `user_id`; sem delete, a linha sai junto com o usuário por
`on delete cascade`).

| Coluna | Tipo | Padrão |
| --- | --- | --- |
| `user_id` | uuid, chave primária, `default auth.uid()` | |
| `enabled_kinds` | `text[]`, não vazio, só `fixed`, `hourly`, `one_off` | os três |
| `non_business_day` | `text`: `next`, `previous` ou `keep` | `next` |
| `overdue_morning_enabled` / `overdue_morning_time` | `boolean` / `time` | `true` / `08:00` |
| `overdue_evening_enabled` / `overdue_evening_time` | `boolean` / `time` | `true` / `19:00` |
| `due_today_enabled` / `due_today_time` | `boolean` / `time` | `true` / `08:00` |
| `updated_at` | `timestamptz` | `now()` |

Conta sem linha usa os padrões. A linha só é criada no primeiro salvamento (`upsert` por
`user_id`). (Tabela em vez de `user_metadata`, como no avatar: decisão de quem desenhou, porque as
regras de checagem e a RLS ficam no banco como nas outras tabelas.)

### Como o app carrega

- As configurações entram no `IncomeSnapshot` e vêm no mesmo `load()` das receitas. O cálculo de
  datas e os avisos dependem delas, e a tarefa em segundo plano já usa esse `load()`, então os avisos
  de segundo plano também respeitam a configuração.
- Snapshot vazio e conta sem linha usam os padrões.
- Outro aparelho vê a mudança no próximo `load()`/`refresh()` (desbloqueio, volta ao primeiro plano,
  pull to refresh, virada do dia ou tarefa em segundo plano). Sem tempo real.

### Tipos de receita

- O `Picker("Tipo")` mostra só os tipos ligados, na ordem de hoje.
- O seletor só existe no cadastro (`if draft.isNew` no `IncomeFormView`). A edição não mostra o tipo
  e não deixa trocá-lo, então desligar um tipo não afeta a edição de receitas existentes.
- Nova receita começa no primeiro tipo ligado. Com um tipo só, o seletor some e o formulário já abre
  nele. (Decisão de quem desenhou.)
- Receitas de tipo desligado continuam nas listas, na home, nas atrasadas e nos avisos.
- Na tela de configurações, o último tipo ligado fica com o toggle desabilitado e uma frase curta
  explica que pelo menos um tipo precisa ficar ligado.

### Dia não útil

Vale para Fixa e Por hora. Avulsa continua na data informada.

| Opção | Texto na tela | Regra |
| --- | --- | --- |
| `next` | Próximo dia útil | primeiro dia útil a partir do dia escolhido (hoje) |
| `previous` | Dia útil anterior | último dia útil até o dia escolhido |
| `keep` | Manter a data | o próprio dia, mesmo em fim de semana ou feriado |

- "Dia útil anterior" pode cair no mês anterior. Exemplo: receita do dia 1 de novembro de 2026
  (domingo) vence na sexta, 30 de outubro. A ocorrência continua sendo de novembro (é o recebimento de
  novembro), só a `dueDate` fica em outubro. Isso precisa funcionar em tudo que filtra por data:
  - a ocorrência aparece como "hoje" e entra nos avisos no dia 30 de outubro (o `dueItems` já inclui o
    mês seguinte);
  - se não for recebida, fica atrasada a partir de 31 de outubro, aparece na aba Atrasadas, no badge,
    no "Falta receber" e nos avisos de atraso, mesmo o mês atual ainda sendo outubro;
  - na aba Receitas e na home ela continua listada em novembro. Enquanto estiver atrasada, também
    aparece na lista de outubro junto com as atrasadas de meses anteriores, do mesmo jeito que
    `occurrences(in:)` já faz hoje com `overdue(before:)`. Assim lista, badge, aba Atrasadas e
    "Falta receber" do mês atual batem. (Decisão de quem desenhou.)
- Mudar a regra muda as datas de todas as ocorrências, passadas e futuras, inclusive o status
  (pendente ou atrasada) de ocorrências sem recebimento. Recebimentos já registrados não mudam.
- Os textos que hoje dizem "próximo dia útil" (`IncomeFormat` e a ajuda do `IncomeFormView`) passam a
  seguir a regra: "próximo dia útil", "dia útil anterior" ou nada a mais (só "Todo dia 15").

### Avisos

- Cada aviso tem liga/desliga e horário com hora e minuto. (Minutos: decisão de quem desenhou.)
- Padrões: atrasadas de manhã 08:00, atrasadas à noite 19:00, prevista para hoje 08:00.
- Aviso desligado não é agendado. Os outros continuam iguais.
- Os horários são livres. Se os dois de atraso ficarem no mesmo horário, sai um aviso só nesse
  horário. A ordem "manhã antes da noite" não é obrigatória; os nomes são só rótulos. (Decisão de
  quem desenhou.)
- `Reminder` passa a ter hora e minuto, e o trigger do `SystemReminderCenter` deixa de usar
  `minute: 0` fixo. Os ids ganham o minuto (`overdue-AAAA-MM-DD-HHMM`) para não colidir quando dois
  avisos ficam na mesma hora com minutos diferentes. O reagendamento já remove todos os pendentes.
- A janela de 14 dias continua. No máximo 42 avisos pendentes, como hoje.
- A seção de avisos mostra uma frase quando a permissão de notificação do iOS está negada, dizendo
  para liberar nos Ajustes. Não abre os Ajustes nem pede permissão de novo. (Decisão de quem
  desenhou.)
- Se a permissão ainda não foi pedida (`notDetermined`), a primeira mudança na seção Avisos pede a
  permissão, mesmo sem receita cadastrada, e grava a marca de "já pedi" usada hoje pelo
  `ReminderScheduler`. (Decisão de quem desenhou.)

### Tela

- Item "Configurações" (`gearshape`) no menu do avatar, acima de "Bloquear". Abre numa sheet com
  `NavigationStack`, título "Configurações" e botão "OK" para fechar. (Decisão de quem desenhou.)
- `Form` com as três seções, nesta ordem: Tipos de receita, Dia não útil, Avisos.
- Dia não útil: `Picker` com as três opções e uma linha de exemplo embaixo, por exemplo "Dia 1 de
  novembro de 2026 cai em 30 de outubro". (Exemplo: decisão de quem desenhou; quem constrói pode
  trocar por outro texto curto.)
- Avisos: para cada um, um toggle e, quando ligado, um `DatePicker` só de hora.
- Cada mudança salva sozinha, sem botão "Salvar". (Decisão de quem desenhou.) O salvamento grava só
  as colunas que mudaram, para que dois aparelhos ou dois saves seguidos não sobrescrevam um ao outro
  (`upsert` por `user_id` só com as colunas alteradas; se a linha ainda não existe, as outras colunas
  ficam com o padrão do banco, que é igual ao padrão do app). Durante o salvamento o
  campo fica desabilitado. Se falhar, o valor volta ao anterior e aparece a mensagem de erro da
  seção, no padrão das outras telas (`IncomeError.network` / `.unknown`).
- Ao mudar, o snapshot local já recebe o valor novo e os avisos são reagendados na hora, pelo mesmo
  caminho que o `RootView` usa quando o snapshot muda com o app aberto. Se o salvamento falhar, o
  valor volta e os avisos são reagendados de novo.
- Se o snapshot ainda não carregou ou falhou, a tela mostra o mesmo estado de carregando/erro da aba
  Receitas, com tentar de novo.

### Sair da conta

O `IncomeStore.reset()` já volta o snapshot para vazio; com isso as configurações voltam aos padrões
até o próximo login carregar as da conta nova.

## Como validar

- Testes de `BusinessCalendar` para as três regras: dia útil, sábado, domingo, feriado, véspera de
  feriado prolongado e "anterior" atravessando o mês (1º de novembro de 2026, domingo).
- Testes de `IncomeSchedule`/`IncomeStore`:
  - mudar a regra muda o `dueDate` de Fixa e Por hora e não muda Avulsa;
  - o valor da Por hora não muda com a regra;
  - ocorrência do mês seguinte com `dueDate` no mês atual aparece em `overdueOccurrences`, no badge
    e no `summary` do mês atual quando atrasada, e em `dueItems` quando vence hoje.
- Testes do `ReminderPlanner`: aviso desligado não sai; horário com minuto; dois avisos de atraso no
  mesmo horário viram um; ids com minuto; aviso cujo horário já passou hoje não sai.
- Testes do serviço/store: conta sem linha usa os padrões; salvar faz `upsert`; erro de salvamento
  devolve o valor anterior; salvar reagenda.
- Teste do formulário: só os tipos ligados aparecem no cadastro; nova receita começa no primeiro tipo
  ligado; não dá para desligar o último tipo.
- Migration aplicada no Supabase com as checagens: `enabled_kinds` vazio ou com valor desconhecido é
  rejeitado; outro usuário não lê nem altera a linha.
- Manual no iPhone e no iPad: mudar uma configuração no iPhone, abrir o iPad e ver o mesmo valor;
  mudar o horário de um aviso e conferir que ele chega no novo horário; desligar um aviso e conferir
  que ele não chega.

## Deixado para quem constrói

- Nomes de tipos, arquivos e da migration, seguindo o padrão do projeto.
- Se as configurações viram um tipo próprio dentro do `IncomeSnapshot` ou um campo ao lado dele, e
  qual store expõe o salvamento, desde que a tarefa em segundo plano use as configurações carregadas.
- Layout fino da tela e textos de ajuda de cada seção.
- Como representar `time` do Postgres no Swift (por exemplo hora e minuto inteiros).
