# Comprometido no cartão

Data: 2026-10-22

Mockup validado com o dono (opção A): `docs/superpowers/mockups/2026-10-22-comprometido-no-cartao.html`.

## Por quê

O dono quer uma visão global de quanto da renda dos próximos meses já está comprometido nos cartões de
crédito, somando todos os cartões. Ele revisa isso uma vez por mês para saber duas coisas:

- o que está terminando: compras parceladas que acabam e quando o valor fica livre;
- o que é fixo: assinaturas e cobranças recorrentes que continuam todo mês até ele cancelar.

Hoje essa informação está espalhada nos apps de C6, Caixa, Nubank e Inter, e nenhum deles projeta os
próximos meses.

## Objetivo

- Cada usuário conecta os próprios cartões numa área de Configurações, pelo MeuPluggy.
- Sincronizar todo dia as transações dos cartões conectados pela Pluggy (Open Finance).
- Nova aba **Cartões** com o comprometido do próximo mês (parcelas + fixos), um gráfico de 12 meses, a
  lista do que está terminando e a lista dos fixos, com filtro por cartão.
- Detectar assinaturas e recorrentes e pedir confirmação do dono antes de contá-las como fixo.

## Fora do escopo

- Conectar pelo Open Finance direto da Pluggy, sem MeuPluggy.
- Conta corrente, saldo, limite do cartão, fatura atual e gastos avulsos do cartão.
- Integrar com a aba Despesas ou com a Home. Os fixos do cartão não aparecem nas despesas fixas e não
  entram no saldo do mês.
- Categorias, orçamento e alertas.
- Separar cobranças por pessoa (cartão adicional, assinatura de outra pessoa). Tudo no cartão conta como
  comprometido do dono.
- Editar transações ou parcelas à mão.

## Anti-objetivos

- Contar como fixo algo que o dono não confirmou. Um gasto frequente (a sorveteria) não é assinatura.
- Contar a mesma compra parcelada duas vezes.
- Expor `PLUGGY_CLIENT_SECRET` no app. A Pluggy só é chamada pelo servidor.
- Uma pessoa ver cartão, transação ou conexão de outra.
- Depender de o dono abrir o app para os dados atualizarem.

## Estado atual (para quem vai construir)

- App iOS 26, Swift 6, SwiftUI, Supabase (Auth, Postgres com RLS) via `supabase-swift`, XcodeGen,
  Swift Testing. Abas em `Financas/Home/AppTab.swift`: `home`, `incomes`, `expenses`, `overdue`.
- Convenções de banco: tabelas em `public` com `user_id uuid default auth.uid()`, RLS por
  `auth.uid() = user_id`, migrations em `supabase/migrations`. Exemplo:
  `20261017040000_create_expenses.sql`.
- Não existe Edge Function no projeto ainda. Esta feature cria a primeira (`supabase/functions`).
- Layout do iPad: `docs/superpowers/specs/2026-10-17-layout-ipad-design.md`.
- Referência de integração com a Pluggy que já funciona: o projeto `~/Code/contas`
  (`src/lib/feeds/pluggy.ts`). Ele usa as mesmas credenciais e os mesmos itens.

## O que sabemos da Pluggy (probe de 2026-10-22)

Rodado contra os itens reais. Snapshots em
`/private/tmp/claude-501/-Users-adriano-Code-financas/f15d2d69-606e-4d42-ba3f-528e77d020b2/scratchpad/pluggy-probe/snapshots`
(temporário).

- Autenticação: `POST /auth` com `clientId` e `clientSecret` devolve `apiKey`, usado no header
  `X-API-KEY`. O `contas` reaproveita a chave por 100 minutos.
- Transações: só `GET /v2/transactions?accountId=&dateFrom=&dateTo=`, paginado por cursor
  (`next` é a query string da próxima página). O endpoint v1 retorna 410 para essas contas.
- Cartões: `GET /accounts?itemId=&type=CREDIT`. Cada item tem um cartão.
- Os quatro bancos mandam em toda parcela `creditCardMetadata` com `installmentNumber`,
  `totalInstallments`, `purchaseDate` e `cardNumber`. `billForecastDate` vem em quase todas;
  `billPostDate` falta em dois bancos. `totalAmount` não vem pelo Open Finance.
- A data da transação nem sempre cai no mês da fatura: no Nubank, as 13 parcelas caem na fatura do mês
  seguinte ao da data.
- Um mesmo cartão (conta da Pluggy) tem vários `cardNumber`, entre virtual e adicional (12 no Nubank).
- A primeira parcela pode ter centavos diferentes das outras (PlayStation C6: 1/4 de R$ 112,49 e 2/4,
  3/4 de R$ 112,47, mesmo `purchaseDate`).
- Transações têm `status` `POSTED` ou `PENDING`, e `type` `DEBIT` ou `CREDIT`.
- Os quatro itens são MeuPluggy: auto-sync da Pluggy a cada 24h e sem atualização sob demanda (`PATCH`).
  A transação chega na Pluggy de 1 a 2 dias depois da compra (mediana), com cauda de até 7 dias.

## Decisões

### Conexões

Outras pessoas usam o app, então cada usuário conecta os próprios cartões. Não há conexão fixa nem seed.
O dono também reconecta os quatro cartões dele pela tela (os itens do `contas` não são reaproveitados).

**Forma de conexão: MeuPluggy** (decisão do dono). A pessoa tem uma conta grátis no MeuPluggy, conecta
os bancos lá pelo Open Finance e autoriza o app. O widget Pluggy Connect abre restrito ao conector
MeuPluggy (`connectorIds: [200]`), como o `contas` faz em `src/app/conexoes/conectar.tsx`. Open Finance
direto pela Pluggy (plano pago por conexão) fica fora.

**Área de conexões**: em Configurações, seção **Cartões conectados** (mockup em
`docs/superpowers/mockups/2026-10-22-comprometido-no-cartao-dispositivos.html`):

- Lista cada conexão com instituição, cartões dela, status e "Atualizado em <data>".
- **Conectar banco**: antes do widget, uma tela explica em três passos que é preciso ter conta no
  MeuPluggy, com botão para criar a conta (link externo) e **Continuar**, que abre o Pluggy Connect
  dentro do app.
- **Reconectar**: aparece quando a conexão precisa de ação da pessoa (erro de login, consentimento
  vencido). Abre o Pluggy Connect com o `itemId` da conexão.
- **Remover**: confirma, apaga o item na Pluggy e apaga do Supabase a conexão, os cartões, as transações
  e as decisões de recorrência dela.
- Sem conexão nenhuma, a aba Cartões mostra um estado vazio com o botão **Conectar banco**, que leva
  para essa área.

**Servidor** (Edge Function, nunca o app falando com a Pluggy):

- Gera o connect token (`POST /connect_token`) amarrado ao usuário logado (`clientUserId` = id do
  usuário no Supabase), com `itemId` quando for reconexão.
- Registra o item que o widget devolveu: busca o item na Pluggy e só grava se o `clientUserId` dele for
  o do usuário logado. Isso impede alguém de registrar o item de outra pessoa.
- Remove o item (`DELETE /items/{id}`) e os dados dele.
- Confirmar na documentação da Pluggy os nomes exatos de `clientUserId` no connect token e no item.

Tabela `card_connections` (`user_id`, `item_id`, `status`, `last_synced_at`, `last_error`), com RLS
como o resto do app.

**Nome do cartão**: nos itens MeuPluggy o conector se chama "MeuPluggy" e a Pluggy não informa o banco.
A conta de cartão traz só `name` (ex.: "BANDEIRADO", "CAIXA VISA PLATINUM CREDITO"), `number` (final) e
`creditData.brand`/`level`. Cada cartão tem um **apelido**, que começa como `name` sem espaços sobrando +
" ····" + final, e pode ser trocado em Cartões conectados (ex.: "C6"). O apelido é o que aparece nos
chips do filtro e nas listas. (Decisão de quem desenhou.) Qualquer banco que a pessoa conectar entra; C6, Caixa,
Nubank e Inter foram só os testados no probe.

### Sincronização

- Edge Function `cards-sync` (Deno), com `PLUGGY_CLIENT_ID` e `PLUGGY_CLIENT_SECRET` como secrets do
  Supabase. Usa a service role para gravar.
- Roda todo dia por `pg_cron` + `pg_net`, passando por todas as conexões de todos os usuários. Pode ser
  chamada pelo app (pull to refresh na aba) com o JWT do usuário, sincronizando só as conexões dele.
  Também roda logo depois de uma conexão nova ser registrada, para a aba não ficar vazia até o dia
  seguinte.
- Item com status de erro de login ou consentimento vencido na Pluggy marca a conexão como "precisa
  reconectar"; a aba Cartões e a área de conexões mostram isso. Isso relê o que a Pluggy
  já coletou; não força coleta no banco.
- Para cada conexão: lista os cartões do item, grava em `card_accounts` (nome, final do cartão,
  instituição) e busca as transações de `last_synced_at − 7 dias` até hoje. Na primeira vez, 12 meses.
- Upsert em `card_transactions` pelo `id` da Pluggy: data, descrição, valor, `type`, `status`,
  `installment_number`, `total_installments`, `purchase_date`, `card_number`.
  Transação `PENDING` que vira `POSTED` é a mesma linha (mesmo `id`). Se o `id` mudar entre pendente e
  lançada, o builder decide como deduplicar e registra no plano.
- Erro numa conexão grava `last_error` e não interrompe as outras. A aba mostra "C6 sem atualizar desde
  12/10" quando `last_synced_at` passar de 3 dias.

### Mês de referência

O comprometido de um mês é a soma do que é lançado no cartão naquele mês, pela data da transação
(`date` da Pluggy). Não é o valor da fatura que vence no mês. (Decisão do dono.) Vale para parcelas e
fixos. `billForecastDate` e `billPostDate` não são usados.

### Parcelas

- "Cartão" é a conta de cartão da Pluggy (`card_accounts`), não o `card_number`: uma compra no cartão
  virtual e outra no físico são do mesmo cartão.
- Uma compra parcelada é identificada por cartão + `purchase_date` + `total_installments` + descrição
  normalizada (sem "NN/NN", espaços e pontuação). O valor não entra na chave, por causa dos centavos da
  primeira parcela.
- Valor da parcela: o da parcela de maior número vista.
- Mês de cada parcela: mês da data da transação. Parcelas que faltam são projetadas uma por mês depois
  da última vista, até `total_installments`.
- Compra parcelada termina no mês da última parcela. "Libera em" é o mês seguinte.
- Se a próxima parcela esperada não aparecer em 2 meses, a compra sai da projeção (estorno ou
  cancelamento).
- Parcelas entram no comprometido sem confirmação, porque vêm marcadas pelo banco.
- Cálculo no app, em Swift, testável (mesmo padrão de `ExpenseSchedule`).

### Fixos (assinaturas e recorrentes)

- Candidato: transações `DEBIT` sem parcela, no mesmo cartão, com a mesma descrição normalizada, em 3 ou
  mais meses diferentes nos últimos 12, com valores até ±10% da mediana. Mesmo critério do probe, que
  achou Wellhub, Spotify, Clube Livelo, iFood Club, Apple, Amazon Music e anuidades.
- Candidato novo fica **para revisar**. A aba mostra "3 recorrências para revisar" no topo; a lista
  deixa marcar **Fixo** ou **Não é fixo**. A decisão fica gravada em `card_recurrences` (`user_id`,
  `card_account_id`, `merchant_key`, `status` `confirmed` ou `dismissed`). Descartado não volta a ser
  sugerido.
- Fixo confirmado conta todo mês com o valor da última cobrança, a partir do próximo mês, sem fim.
- Fixo confirmado sem cobrança há mais de 45 dias aparece com "sem cobrança recente" e continua
  contando. O dono pode encerrar o fixo, e aí ele para de contar (status `ended`).
- Fixo encerrado que volta a ser cobrado depois da data em que foi encerrado volta para revisar, com
  "cobrado depois de encerrado". (Decisão de quem desenhou: uma assinatura que o dono achou que cancelou
  e segue cobrando não pode sumir do comprometido.)
- Detecção no app, em Swift, testável.

### Aba Cartões

Quinta aba, depois de Despesas: **Cartões**. Conteúdo, de cima para baixo (mockup opção A):

1. Aviso de recorrências para revisar, quando houver.
2. Filtro: Todos, e um chip por cartão com o apelido do cartão. Padrão: Todos.
3. Painel: "Comprometido em <próximo mês>" com o total, separado em parcelas e fixos. Gráfico de barras
   empilhadas (parcelas em azul, fixos em roxo) dos próximos 12 meses.
4. **Terminando**: parcelas cuja última parcela cai nos próximos 3 meses, com o nome, o cartão, "N/N em
   <mês>", o valor da parcela e "libera em <mês>". "Ver parcelas" abre todas as parcelas em andamento,
   ordenadas pelo mês de término.
5. **Fixos**: os fixos confirmados, com nome, cartão e valor. "Ver todos" abre a lista completa, onde dá
   para encerrar um fixo.

No iPad, ao lado do título, "Atualizado <quando>" com a sincronização mais antiga entre as conexões. Na
barra lateral, Cartões mostra como contador o número de recorrências para revisar. (Decisões de quem
desenhou, vistas no mockup de dispositivos.)

"Próximo mês" é o mês seguinte ao atual. O filtro muda todos os blocos. Não há tela de detalhe de uma
compra parcelada ou de um fixo nesta versão.

No iPad, a aba usa duas colunas: aviso, filtro e painel à esquerda; Terminando e Fixos à direita. Não
usa o padrão de lista com detalhe ao lado. (Decisão de quem desenhou: a aba é um painel, sem item para
abrir em detalhe.)

## Fica com o builder

- Nome das tabelas e colunas além das citadas, índices e formato da migration de seed.
- Horário do `pg_cron`.
- Normalização exata da descrição, desde que agrupe "WELLHUB ADRIANO GONCAL SAO PAULO BRA" de meses
  diferentes e separe "WELLHUB CRISTIANO GONC" de "WELLHUB ADRIANO GONCAL".
- Visual do gráfico, estados vazio e de carregamento, seguindo os componentes de vidro do app.
- Como o app chama a Edge Function no pull to refresh.

## Como validar

- Testes de unidade do agrupamento de parcelas com o caso PlayStation C6 (1/4 R$ 112,49 e 3/4
  R$ 112,47, mesmo `purchaseDate` → uma compra, falta 1 parcela).
- Testes da detecção de recorrência: Wellhub em 6 meses vira candidato, gasto com valores variando mais
  de 10% não vira, item descartado (a Gelateria do probe, que passa no critério) não volta.
- Teste de mês de referência: parcela com data em abril e previsão de fatura em maio conta em abril.
- Depois da primeira sincronização real, conferir as parcelas de um mês passado contra a soma manual das
  transações parceladas daquele mês nos snapshots do probe.
