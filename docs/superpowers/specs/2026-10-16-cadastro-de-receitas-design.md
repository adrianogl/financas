# Cadastro de receitas

Data: 2026-10-16

## Por quê

O dono recebe de duas empresas todo mês e hoje confere na conta corrente se cada pagamento caiu. Ele
quer abrir o app e ver o que falta receber no mês e quando cada valor cai, e marcar cada recebimento
quando o dinheiro entra. É a primeira funcionalidade com dados reais. Até aqui, o app tinha só conta,
desbloqueio e uma home com dados de exemplo.

## As receitas do dono hoje

| Receita | Valor | Quando cai |
| --- | --- | --- |
| Fixa | R$ 13.020,04 por mês | Dia 1, ou o próximo dia útil |
| Por hora | R$ 90/h × 8 h × dias úteis do mês anterior | Dia 15, ou o próximo dia útil |

O pagamento por hora do dia 15 cobre o mês anterior inteiro. Se o dono não trabalha num dia, não
recebe por ele. Se trabalha num feriado, recebe a hora normal. O valor da hora pode subir no futuro.

Exemplo: outubro de 2026 tem 22 dias de semana, menos o feriado de 12/10, o que dá 21 dias úteis.
A previsão é 21 × 8 × 90 = R$ 15.120,00. O pagamento seria em 15/11/2026, mas esse dia é domingo e
feriado, então vai para segunda, 16/11.

## Objetivo

- Cadastrar receitas recorrentes (mensais) e avulsas.
- Receita recorrente de valor fixo ou por hora.
- Regra de data: um dia do mês; se não for dia útil, o próximo dia útil.
- Para cada mês, o app gera a ocorrência de cada receita, com data e valor previstos.
- Cada ocorrência fica pendente até o dono marcar como recebida, informando data e valor reais. Uma
  pendente com a data já passada aparece como atrasada.
- A home mostra quanto falta receber no mês, quantas receitas estão atrasadas e a próxima data.
- Os dados ficam no Supabase, presos à conta, e aparecem em qualquer aparelho.

## Fora do escopo

- Despesas. A barra de abas tem só Início e Receitas.
- Saldo e "Últimos lançamentos" reais. Esses cards da home continuam com dados de exemplo, e o
  rótulo "Valores de exemplo" passa a valer só para eles.
- Feriados estaduais e municipais. O dono ajusta os dias ao marcar a receita como recebida.
- Recorrência que não seja mensal (semanal, quinzenal, anual).
- Uso offline. Sem internet, a aba de receitas mostra o erro e um botão para tentar de novo.
- Notificações de receita atrasada.
- Importar extrato do banco.

## Anti-objetivos

- O dono não pode ter que cadastrar todo mês a mesma receita. Ele cadastra uma vez e o app gera o
  resto.
- Mudar o valor de uma receita não pode alterar meses anteriores, nem os já recebidos nem os
  pendentes antigos.
- Marcar como recebida não pode exigir digitação no caso normal: tudo vem preenchido com o previsto.
- Os dados de uma conta não podem ser lidos por outra. Toda tabela tem RLS desde a primeira
  migration.

## Estado atual (para quem vai construir)

Projeto iOS em SwiftUI, gerado pelo XcodeGen (`project.yml`), mínimo iOS 26, Swift 6, Liquid Glass,
`supabase-swift` 2.55.4. A conta (`Financas/Account/`) já está pronta: `AccountManager`, que fala com
o Supabase por `AccountService`, com fake nos testes. `RootView` mostra `HomeView` depois do
desbloqueio. A home (`Financas/Home/HomeView.swift`) tem o cumprimento, o card de saldo com gráfico e
o card "Últimos lançamentos", todos com dados de `HomeConstants`.

Identidade visual em `Financas/Shared/Theme.swift` e `AppBackground.swift`. Destaque azul
(`Color.accentColor`, `#3D6FE0` no claro), `Theme.positive` (verde) só em valor positivo, fundo
`AppBackground` com manchas desfocadas, cards com `.glassEffect(.regular, in: .rect(cornerRadius: 26))`,
ícones brancos em círculo de 36 pt com `Theme.categoryTints` (ver `TransactionRow`).

Convenções do dono: sem comentários no código; um tipo por arquivo; constantes em `*Constants.swift`
da pasta da feature; textos da interface em português; testes com Swift Testing em `FinancasTests`.

## Decisões

### Ocorrências calculadas, recebimentos gravados

O banco guarda as receitas cadastradas, o histórico de valores e os recebimentos. As ocorrências
pendentes não são gravadas: o app calcula a partir das regras para o mês que está na tela. Uma
ocorrência passa a existir no banco só quando é marcada como recebida.

Descartado: gerar uma linha por mês no banco. Exigiria um job mensal e ficaria desatualizado sempre
que o dono mudasse a regra de uma receita.

### Tipos de receita

- **Recorrente de valor fixo**: valor mensal, dia do mês, mês de início, mês de fim opcional.
- **Recorrente por hora**: valor da hora, horas por dia, dia do mês, mês de início, mês de fim
  opcional. A ocorrência paga em um mês se refere aos dias trabalhados no mês anterior.
- **Avulsa**: nome, data e valor. Não usa a regra de dia útil: cai na data informada.

A recorrente de valor fixo no mês M tem data prevista no dia escolhido de M. A recorrente por hora
paga no mês M tem como referência o mês M−1. A ocorrência pertence ao mês M para efeito de "falta
receber em M", mesmo que o próximo dia útil caia em M+1.

Mês de início: a primeira ocorrência é a do mês de início. Para a por hora, o mês de início é o do
primeiro pagamento, e a referência dele é o mês anterior.

Dia do mês de 1 a 31. Em mês mais curto, usa o último dia do mês e aplica a regra de dia útil a
partir dele. (Decisão de quem desenhou.)

### Valores com vigência

O valor mensal (fixa) e o valor da hora (por hora) ficam numa tabela de vigências: valor e mês a
partir do qual vale. Para calcular uma ocorrência, o app usa a vigência mais recente que começa até o
mês de referência (mês M para a fixa, mês M−1 para a por hora). Para mudar o valor, o dono informa o
novo valor e o mês a partir do qual vale. As ocorrências antes desse mês ficam como estavam.

Horas por dia ficam na própria receita, sem vigência. (Decisão de quem desenhou: o dono não falou em
mudar as 8 h.)

### Dia útil e feriados

Dia útil é de segunda a sexta, menos os feriados do calendário bancário nacional:

- fixos: 1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11, 25/12;
- móveis, calculados a partir da Páscoa: segunda e terça de Carnaval, Sexta-feira Santa e Corpus
  Christi.

O mesmo calendário define a data de pagamento (próximo dia útil) e os dias úteis do mês de
referência da receita por hora. Carnaval e Corpus Christi entram porque os bancos não abrem nesses
dias. (Decisão de quem desenhou. Se o dono trabalhar num desses dias, ajusta os dias ao marcar como
recebida.)

O calendário é calculado no app, sem tabela e sem API externa. "Hoje" e as datas usam o calendário e
o fuso do aparelho.

### Previsão da receita por hora

Dias úteis do mês de referência × horas por dia × valor da hora vigente no mês de referência.

### Status da ocorrência

- **Recebida**: existe recebimento gravado.
- **Atrasada**: sem recebimento e com data prevista anterior a hoje.
- **Pendente**: sem recebimento e com data prevista hoje ou depois.

### Atrasadas de meses anteriores

Uma ocorrência atrasada continua aparecendo no mês atual até ser marcada como recebida (pedido do
dono). Para isso, o app calcula as ocorrências de cada receita desde o mês de início até o mês
atual e cruza com os recebimentos.

- No mês atual, o "falta receber" soma as pendentes e atrasadas do mês mais as atrasadas de meses
  anteriores. A seção "Pendentes" mostra essas atrasadas antigas primeiro, com o mês de referência na
  linha ("Por hora · setembro").
- Num mês passado no seletor, a aba mostra só as ocorrências daquele mês, com o status de hoje.
- Num mês futuro, só as daquele mês, todas pendentes.

### Resumo do mês

- **Recebido**: soma dos valores recebidos de fato nas ocorrências do mês.
- **Falta**: soma dos previstos das ocorrências sem recebimento. No mês atual, inclui as atrasadas
  de meses anteriores.
- **Previsto**: recebido + falta. Quando um valor recebido é diferente do previsto, o previsto do mês
  acompanha o que entrou de fato. A linha da ocorrência recebida mostra o previsto original ao lado
  quando os dois forem diferentes. (Decisão de quem desenhou: a barra de progresso fecha em 100%
  quando tudo foi recebido.)

Exemplo: a fixa de outubro entra R$ 13.000,00 e a por hora está pendente com R$ 15.120,00. Recebido
R$ 13.000,00, falta R$ 15.120,00, previsto R$ 28.120,00.

### Marcar como recebida

Uma sheet com o previsto em destaque e os campos já preenchidos:

- Por hora: dias trabalhados (padrão: dias úteis do mês de referência), horas (padrão: dias × horas
  por dia) e valor da hora (vigente, só leitura). Mudar os dias recalcula as horas. Mudar as horas
  recalcula o valor previsto exibido.
- Todas: data do recebimento (padrão: hoje) e valor recebido (padrão: o valor previsto, já
  recalculado).

O recebimento grava data, valor recebido e, na por hora, dias e horas informados. Uma ocorrência
recebida pode ser editada ou desmarcada (volta a pendente ou atrasada).

O valor recebido pode ser diferente do previsto sem precisar de justificativa.

### Encerrar e excluir

- Encerrar uma recorrente define o mês de fim. As ocorrências até esse mês continuam aparecendo, e as
  recebidas ficam no histórico.
- Excluir apaga a receita, as vigências e os recebimentos, com confirmação na própria tela (o app não
  usa `alert`). O fluxo normal para uma receita que acabou é encerrar.

### Telas

Validadas com o dono em mockup, seguindo a identidade do app.

**Barra de abas.** `TabView` com Início e Receitas, em vidro, no estilo flutuante do iOS 26. O menu
de conta (Bloquear, Sair da conta) continua na toolbar da home.

**Home.** Um card novo entre o saldo e "Últimos lançamentos":

- rótulo "Falta receber em outubro";
- valor que falta, grande, incluindo as atrasadas de meses anteriores;
- selo "1 atrasada" quando houver atrasadas;
- barra de progresso em azul com o quanto já entrou e a legenda "R$ 13.020,04 de R$ 28.140,04 já
  entrou";
- linha "Próxima: Fixa · ter, 3 nov", com a próxima ocorrência pendente (deste mês ou do seguinte).

Tocar no card abre a aba Receitas no mês atual. Se não houver receita cadastrada, o card mostra um
convite para cadastrar a primeira receita.

**Aba Receitas.**

- Título "Receitas" e "+" na toolbar para criar uma receita.
- Seletor de mês em vidro ("‹ Outubro de 2026 ›").
- Resumo do mês: recebido (verde), falta e previsto.
- Seção "Pendentes", com as atrasadas primeiro e o selo "atrasada", em ordem de data. A linha da por
  hora mostra o mês de referência e a conta ("qui, 15 out · 21 dias × 8h").
- Seção "Recebidas", com o valor em verde.
- Seção "Cadastradas", com as recorrentes ativas e a regra resumida ("Todo dia 15 · R$ 90/h ·
  8h/dia"). Tocar abre a edição. No fim, um link "Encerradas" abre a lista das recorrentes
  encerradas. A avulsa não aparece aqui: ela é editada tocando na ocorrência do mês dela. (Decisão de
  quem desenhou.)

**Criar e editar receita.** Formulário com tipo (recorrente fixa, recorrente por hora, avulsa) e os
campos do tipo. Para mudar o valor de uma recorrente, um campo "a partir de" com o mês. Na edição,
as ações Encerrar e Excluir.

**Marcar recebida.** Sheet em vidro, como descrito acima. Botão principal "Marcar como recebida".

**Cor de atraso.** O tema não tem cor de alerta. Entra uma cor nova no `Theme` para o selo
"atrasada": `#C9483B` no claro, com variante para o escuro, sempre em fundo translúcido da mesma cor.
Usada só no selo.

Mockup de referência:
`.superpowers/brainstorm/57707-1792197486/content/receitas-c-identidade.html`.

### Banco no Supabase

Três tabelas no schema `public`, todas com `user_id uuid not null default auth.uid()`, chave
estrangeira para `auth.users` com `on delete cascade`, RLS ligado e políticas de `select`, `insert`,
`update` e `delete` restritas a `user_id = auth.uid()`.

- `incomes`: `id`, `user_id`, `name`, `kind` (`fixed`, `hourly`, `one_off`), `day_of_month`
  (recorrentes), `hours_per_day` (por hora), `start_month` e `end_month` (recorrentes, guardados como
  `date` no dia 1), `one_off_date` e `one_off_amount` (avulsa), `created_at`.
- `income_amounts`: `id`, `user_id`, `income_id`, `amount`, `valid_from` (`date` no dia 1). Para a
  fixa, `amount` é o valor mensal; para a por hora, o valor da hora.
- `income_receipts`: `id`, `user_id`, `income_id`, `month` (`date` no dia 1, o mês da ocorrência),
  `received_on`, `amount`, `worked_days` e `worked_hours` (só por hora). Único por
  (`income_id`, `month`).

Valores em `numeric(12,2)` e `Decimal` no app. `check` no banco para os campos obrigatórios de cada
`kind`.

As migrations ficam versionadas em `supabase/migrations/` e são aplicadas no projeto pelo MCP do
Supabase. Depois de cada migration, rodar os advisors de segurança e não seguir com aviso de RLS
aberto.

### Arquitetura

- Funções puras, sem Supabase, cobertas por testes:
  - `BusinessCalendar`: feriados do ano, "é dia útil", próximo dia útil, dias úteis do mês;
  - cálculo das ocorrências de um mês a partir das receitas, vigências e recebimentos, com status em
    relação a "hoje";
  - atrasadas de meses anteriores ao mês atual, percorrendo cada receita desde o mês de início;
  - resumo do mês (recebido, falta, previsto, atrasadas, próxima).
- `IncomeStore` (`@MainActor @Observable`): carrega receitas, vigências e recebimentos, expõe o mês
  em tela e as ações (criar, editar, encerrar, excluir, marcar e desmarcar recebida). Fala com o
  Supabase por um protocolo, com implementação real usando o cliente que a conta já cria e fake nos
  testes, como `AccountService`.
- `HomeView` e a aba Receitas leem do mesmo `IncomeStore`, injetado no ambiente.

## Como validar

- Testes do `BusinessCalendar` com datas reais: feriados de 2026 e 2027 (incluindo Carnaval, Sexta
  Santa e Corpus Christi), 15/11/2026 → 16/11/2026, 1/11/2026 → 3/11/2026 (domingo e Finados),
  outubro de 2026 com 21 dias úteis, setembro de 2026 com 21 dias úteis.
- Testes das ocorrências: fixa e por hora em outubro e novembro de 2026; status pendente, atrasada e
  recebida em relação a uma data "hoje" fixa; mudança do valor da hora a partir de um mês sem alterar
  os anteriores; mês de início e mês de fim; dia 31 em fevereiro; avulsa; por hora de setembro sem
  recebimento aparece e é somada em outubro; resumo com valor recebido diferente do previsto.
- Testes do `IncomeStore` com o fake: marcar e desmarcar recebida, erro de rede mantém o estado
  anterior e mostra mensagem.
- Advisors de segurança do Supabase sem aviso nas tabelas novas.
- Manual no simulador: cadastrar as duas receitas do dono a partir de outubro de 2026 e conferir a
  home e a aba com os valores deste documento. Marcar a por hora de outubro com 20 dias, ver o resumo
  mudar. Abrir no segundo simulador e ver os mesmos dados.

## Deixado para quem constrói

- Layout fino do formulário de receita, dentro da identidade descrita.
- Nomes de tipos e arquivos, seguindo o padrão do projeto.
- Como o `IncomeStore` recarrega (ao abrir a aba, ao voltar do segundo plano, depois de cada ação).
- Mensagens exatas de erro, em português e específicas.
