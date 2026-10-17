# Home por mês e avatar da conta

Data: 2026-10-17

## Por quê

A home mostra o mês atual, mas o saldo e os "Últimos lançamentos" ainda são valores de exemplo, e não
dá para olhar outro mês. O dono quer que a home seja a visão geral do mês escolhido, com dados reais.
Hoje o único dado real são as receitas recebidas, então elas alimentam o saldo e os lançamentos até as
despesas existirem.

O botão da conta na toolbar é um ícone genérico (`person.crop.circle`). O dono quer ver a inicial do
nome ou uma foto própria, e a foto deve aparecer em todos os aparelhos da conta.

## Objetivo

- Trocar o mês da home. Saldo, "Falta receber" e lançamentos acompanham o mês escolhido.
- Saldo e lançamentos com dados reais, a partir das receitas recebidas.
- Avatar com a inicial do nome por padrão e opção de enviar ou remover uma foto, guardada no
  Supabase e igual em todos os aparelhos.

## Fora do escopo

- Despesas. Quando existirem, entram no saldo e nos lançamentos (ver "Saldo").
- Tela de comparação entre meses.
- Recortar ou editar a foto além do corte quadrado central automático.
- Saldo inicial da conta bancária. O saldo começa em zero.

## Anti-objetivos

- A foto de uma conta não pode ser lida por outra.
- Sem internet, o avatar não pode ficar vazio: mostra a foto guardada no aparelho ou a inicial.

## Estado atual (para quem vai construir)

Ver também `docs/superpowers/specs/2026-10-16-cadastro-de-receitas-design.md`.

- `Financas/Home/HomeView.swift`: cumprimento com `CollapsingAppLogo`, card de saldo com gráfico
  (`HomeConstants.balancePoints`, `sampleBalance`), `IncomeSummaryCard` e card "Últimos lançamentos"
  com `HomeConstants.sampleTransactions` e `TransactionRow`. Rótulo "Saldo e lançamentos com valores
  de exemplo". Toolbar com `Menu("Conta", systemImage: "person.crop.circle")` com "Bloquear" e "Sair
  da conta".
- `Financas/Income/IncomeStore.swift`: `selectedMonth`, `today`, `snapshot` (receitas, vigências,
  recebimentos), `summary(for:)`, `refresh()` a cada desbloqueio, `reset()` ao sair da conta.
- `Financas/Income/MonthPicker.swift`: seletor "‹ Outubro de 2026 ›" em vidro, já usado na aba.
- `Financas/Account/AccountManager.swift` e `SupabaseAccountService.swift`: o nome vem de
  `user_metadata.name`. `AccountUser` tem `id`, `email`, `name`.
- Um único `SupabaseClient`, criado por `SupabaseClientFactory`.

Convenções do dono: sem comentários no código; um tipo por arquivo; constantes em `*Constants.swift`;
textos em português; testes com Swift Testing.

## Decisões

### Mês da home

- `MonthPicker` logo abaixo do cumprimento, ligado a `IncomeStore.selectedMonth`. É o mesmo mês da
  aba Receitas (decisão de quem desenhou: um mês só no app evita a home e a aba mostrarem meses
  diferentes sem aviso).
- O cumprimento e a data de hoje não mudam com o mês.
- O mês volta ao atual quando o app é aberto do zero e quando o dia vira para um mês novo enquanto o
  mês atual estava na tela (comportamento que o `IncomeStore` já tem). Voltar do segundo plano mantém o
  mês escolhido. (Decisão de quem desenhou: não muda o comportamento da aba Receitas.)

### Saldo

- Fechamento do mês, não acumulado. Rótulo "Saldo de \(mês)" ("Saldo de outubro").
- Valor: soma dos recebimentos com `receivedOn` dentro do mês escolhido. O `DatePicker`
  "Recebido em" do `ReceiptSheet` passa a aceitar só datas até hoje, então não existe recebimento no
  futuro. (Decisão de quem desenhou.) Usa a data em que
  o dinheiro entrou, não o mês da ocorrência (decisão de quem desenhou: uma receita de outubro paga em
  3/11 entra no saldo de novembro, como na conta corrente).
- Gráfico do mês: começa em zero no dia 1 e sobe em cada dia com recebimento, até o fim do mês (ou até
  hoje, no mês atual). Sem recebimentos no mês, a linha é reta em zero.
- Quando as despesas existirem, o saldo passa a ser recebimentos menos despesas, com a mesma regra de
  data.

### Falta receber

O `IncomeSummaryCard` passa a usar o mês escolhido: "Falta receber em \(mês)", resumo de
`summary(for: selectedMonth)`. Tocar abre a aba Receitas no mesmo mês, sem voltar ao mês atual. A
regra de atrasadas de meses anteriores continua valendo só no mês atual.

### Lançamentos do mês

- Título "Lançamentos de \(mês)".
- Lista dos recebimentos com `receivedOn` dentro do mês escolhido, do mais recente para o mais antigo,
  no estilo do `TransactionRow`: ícone do tipo da receita, título da ocorrência ("Por hora ·
  setembro"), legenda "Receita · \(dia)", valor em `Theme.positive` com "+".
- Sem recebimentos: "Nenhum lançamento em \(mês)."
- Os dados de exemplo (`HomeConstants.sample*`, `SampleTransaction`, `BalancePoint`) e o rótulo
  "valores de exemplo" deixam de existir.

### Avatar

- Na toolbar da home, o botão do menu da conta mostra o avatar em círculo de 36 pt no lugar do ícone.
- Sem foto: a primeira letra do nome, em maiúscula, sobre fundo `Theme.markBottom` com a letra em
  `Theme.accent`. Sem nome, a primeira letra do e-mail.
- O menu ganha "Escolher foto" (abre o `PhotosPicker` do sistema, só imagens) e, quando há foto,
  "Remover foto". "Bloquear" e "Sair da conta" continuam.
- A foto escolhida é cortada em quadrado central, reduzida para 512 × 512 e gravada como JPEG com
  qualidade 0,8 antes de enviar. (Decisão de quem desenhou.)
- Enviando: o avatar mostra um `ProgressView` por cima. Em erro, o menu já fechou, então a mensagem
  aparece abaixo do cumprimento, em `Theme.warning`, até a próxima ação. (Decisão de quem desenhou.)

### Foto no Supabase

- Bucket privado `avatars` no Supabase Storage.
- Caminho `\(user_id)/avatar.jpg`. Upload com `upsert`.
- Políticas em `storage.objects` para `authenticated`: `select`, `insert`, `update` e `delete` só
  quando `bucket_id = 'avatars'` e o primeiro segmento do caminho é `auth.uid()`.
- Depois do upload, o app grava `avatar_version` (timestamp em segundos) em `user_metadata`. Remover
  apaga o arquivo e grava `avatar_version = null`. Outros aparelhos sabem que a foto mudou ao comparar
  a versão da sessão com a do cache local.
- A cada desbloqueio, o app busca o usuário no servidor (`auth.user()`) e atualiza nome e
  `avatar_version` no `AccountManager`. Sem internet, mantém o que tem. Assim a foto trocada no iPhone
  aparece no iPad no próximo desbloqueio. (Decisão de quem desenhou.)
- O app baixa a foto pelo client autenticado e guarda no aparelho (pasta de caches), junto com a
  versão. Sem internet, usa o que estiver guardado. Sair da conta apaga a foto guardada.

### Arquitetura

- `HomeMonthSummary` (função pura, testável): a partir do `IncomeSnapshot`, do mês e de hoje, calcula
  o saldo do mês, os pontos do gráfico e os lançamentos do mês.
- `AvatarStore` (`@MainActor @Observable`) dono da imagem do avatar e das ações escolher e remover.
  Fala com o Supabase por um protocolo, com fake nos testes, como `IncomeService`. Também recebe
  `reset()` no `onSignedOut`.
- `AccountUser` ganha `avatarVersion: Int?`, lido de `user_metadata`.
- `AccountService` ganha `refreshUser() async throws(AccountError) -> AccountUser`, e o
  `AccountManager` ganha `refreshUser()`, chamado no desbloqueio junto com `incomeStore.refresh()`.

## Como validar

- Testes do `HomeMonthSummary`: saldo de setembro, outubro e novembro com recebimentos em datas
  diferentes; receita de outubro paga em 3/11 conta em novembro; lançamentos ordenados; mês sem
  recebimento; pontos do gráfico.
- Testes do `AvatarStore` com fake: inicial do nome e do e-mail; escolher foto grava e atualiza a
  versão; remover limpa; versão diferente da do cache baixa de novo; erro de rede mantém a foto atual.
- Teste da redução: imagem 1200 × 800 sai 512 × 512.
- Advisors do Supabase sem aviso; outra conta não lê a foto (SQL com outro `sub`).
- Manual no iPhone: trocar o mês na home e na aba; enviar foto no iPhone e ver no iPad depois de
  desbloquear.

## Deixado para quem constrói

- Layout fino do seletor na home e do aviso de erro.
- Nomes de tipos e arquivos, seguindo o padrão do projeto.
- Como o `PhotosPicker` entrega a imagem (`Transferable`/`Data`).
