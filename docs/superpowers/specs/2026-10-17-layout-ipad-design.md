# Layout para iPad

Data: 2026-10-17

## Por quê

O app roda no iPad (`TARGETED_DEVICE_FAMILY: "1,2"`), mas usa o mesmo layout do iPhone. Home,
Receitas e Atrasadas passam por `readableWidth(LayoutConstants.contentWidth)`, que limita o conteúdo a
uma coluna de 720pt no meio da tela, e as laterais ficam vazias. O dono usa o iPad principalmente na
horizontal, para ver o resumo do mês, e às vezes na vertical. A ideia é usar a largura extra para
mostrar o mês inteiro numa tela e consultar o detalhe de uma receita ou despesa sem sair da lista.

Mockups validados com o dono: `docs/superpowers/mockups/2026-10-17-layout-ipad.html`. É só abrir no
navegador. As abas do topo mostram Início, Receitas, Despesas e o fluxo do iPhone, cada um em iPad
horizontal, iPad vertical e iPhone.

## Objetivo

- No iPad, barra lateral no lugar das abas, com opção de recolher. Recolhida, as seções viram abas no
  topo, e um botão no canto inferior esquerdo abre a barra de novo.
- Home do iPad como painel do mês: saldo com gráfico, números do mês, e receitas e despesas lado a
  lado. Duas colunas com a barra aberta e três com ela recolhida.
- Receitas, Despesas e Atrasadas no iPad com a lista do mês e o detalhe do item selecionado ao lado.
- Tela de detalhe de receita e de despesa, nova também no iPhone. Tocar numa linha passa a abrir o
  detalhe, e não mais a sheet de confirmação.

## Fora do escopo

- Mudar formulários, sheets de confirmação e Configurações. Continuam como sheets e, no iPad,
  aparecem como form sheet centralizada, que é o padrão do sistema.
- Telas de conta, PIN e bloqueio. Já usam `readableWidth()` e ficam como estão.
- Suporte a teclado e atalhos, arrastar e soltar, várias janelas e Mac Catalyst.
- Mudar a Home do iPhone além do que a spec de despesas já define.

## Anti-objetivos

- O iPhone não pode perder nada do que tem hoje, além da troca do toque na linha (ver "Detalhe").
- O app não pode decidir o layout pelo modelo do aparelho. A decisão vem da largura disponível. Um
  iPad em Split View ou Stage Manager estreito deve receber o layout do iPhone, sem cortes.
- Abrir ou recolher a barra, ou girar o iPad, não pode perder o mês selecionado nem o item aberto no
  detalhe.
- O detalhe não pode duplicar a lógica de receber, pagar ou lançar conta. Ele abre as sheets que já
  existem.

## Dependência

Esta spec vem depois das despesas fixas
(`docs/superpowers/specs/2026-10-17-despesas-fixas-design.md`, na branch `feat/despesas-fixas`, em
construção por outro agente). Home, Despesas e Atrasadas do iPad usam os modelos, o store e as sheets
de despesa daquela entrega. O plano desta spec começa a partir do código das despesas já integrado,
inclusive as telas, a sheet, Atrasadas e Home, e usa os nomes reais dos tipos criados lá.

Esta spec muda uma decisão daquela: lá, tocar numa ocorrência de despesa abre direto a sheet de
lançar ou pagar. Aqui, tocar abre o detalhe, e a sheet abre pelos botões do detalhe. A sheet em si
não muda.

## Estado atual (para quem vai construir)

Ler antes: a spec de despesas fixas e
`docs/superpowers/specs/2026-10-17-home-por-mes-e-avatar-design.md`.

- `MainTabView` monta um `TabView` com `Tab(value:)` e labels só com ícone
  (`.labelStyle(.iconOnly)`), `.tabBarMinimizeBehavior(.onScrollDown)` e badge em Atrasadas. Também
  aplica a rota pendente do `ReminderRouter` (aviso tocado), trocando `selectedTab`. No iPadOS, esse
  `TabView` já aparece como barra flutuante no topo.
- `AppTab`: `home`, `incomes`, `overdue`. A spec de despesas acrescenta a aba Despesas.
- `HomeView`: `NavigationStack` com `ScrollView`, header (logo, saudação, data), `MonthPicker`, card
  de saldo com `Chart`, `IncomeSummaryCard`, que vira o card dividido com Falta pagar na spec de
  despesas, e card de lançamentos. O avatar fica na toolbar e abre um `Menu` com foto, Configurações,
  Bloquear e Sair da conta.
- `IncomesView`: `MonthPicker`, `IncomeMonthSummaryCard`, seções Pendentes, Recebidas e Cadastradas.
  Tocar numa ocorrência define `receiving`, e `incomeReceiptFlow(receiving:editing:)` abre a
  `ReceiptSheet`. O menu de contexto da linha tem "Editar receita".
- `ReceiptSheet`: confirma o recebimento (data, valor, dias e horas no caso de hora trabalhada) e,
  quando já recebida, tem "Desmarcar recebimento".
- `OverdueView`, com o card de total e as linhas atrasadas.
- `readableWidth(_:)` em `Shared/ReadableWidth.swift`. `LayoutConstants.formWidth` = 520 e
  `contentWidth` = 720.
- Visual: `AppBackground` (manchas desfocadas), cards com `.glassEffect(.regular, in: .rect(cornerRadius: 26))`,
  `Theme` (accent, positive, warning), `MonthPicker` em vidro, `AppMark` e `AppWordmark`.

Convenções do dono: sem comentários no código; um tipo por arquivo; types e constantes em arquivos
próprios (`*Constants.swift`, `*.types` quando aplicável); textos em português; testes com Swift
Testing em `FinancasTests`; projeto gerado pelo `project.yml`; o app não usa `alert`.

## Decisões

### Quando usar o layout de iPad

O layout depende da largura disponível, não do aparelho:

- **Compacto** (`horizontalSizeClass == .compact`): layout do iPhone, inclusive no iPad em Split View
  estreito.
- **Regular**: barra lateral e os layouts largos desta spec.
- Dentro do regular, a Home escolhe entre duas e três colunas pela largura da área de conteúdo, não
  pela orientação. O ponto de corte fica com quem constrói, desde que, num iPad de 11" na
  horizontal, saiam duas colunas com a barra aberta e três com ela recolhida.
- Onde esta spec diz "horizontal" e "vertical", vale a forma da janela, não a orientação do aparelho:
  horizontal é janela mais larga que alta, vertical é o contrário. Assim, um iPad 13" na vertical
  segue as regras de vertical mesmo tendo largura para duas colunas, e no Stage Manager vale a forma
  da janela. (Decisão de quem desenhou.)

### Navegação

- O `TabView` passa a usar a barra lateral no regular (estilo `.sidebarAdaptable` ou equivalente). No
  compacto, as abas ficam embaixo, como hoje.
- Barra lateral, de cima para baixo: logo do app (`AppMark` e "Finanças"), Início, Receitas,
  Despesas e Atrasadas. Cada seção tem ícone e nome, e Receitas, Despesas e Atrasadas mostram
  contadores. No pé, o avatar com o nome e "Conta e configurações", que abre o mesmo menu do avatar
  de hoje (foto, Configurações, Bloquear, Sair da conta).
- Contadores (decisão de quem desenhou): Receitas e Despesas mostram quantas ocorrências do mês
  selecionado ainda não foram recebidas ou pagas, contando as atrasadas e, no mês atual, as atrasadas
  de meses anteriores. É o mesmo conjunto que entra em "Falta receber" e "Falta pagar". Atrasadas
  mostra o total de atrasadas, na cor `Theme.warning`, igual ao badge de hoje. Os números do mockup
  (4 e 6) estão errados. Vale este texto.
- **Recolher**: a barra tem um botão para recolher. Recolhida, as seções aparecem como abas no topo,
  como o `TabView` já faz no iPad, e um botão flutuante redondo de vidro, no canto inferior esquerdo,
  abre a barra de novo. O dono pediu o botão embaixo e aceitou o custo de não usar o botão do
  sistema.
- O botão do sistema para alternar a barra não deve aparecer junto com o nosso. Se o sistema não
  deixar esconder o botão dele nem controlar a barra por código, quem constrói para e avisa o dono
  antes de trocar o botão de lugar.
- **Estado inicial** (decisão de quem desenhou): na horizontal, o app lembra se a barra ficou aberta
  ou recolhida. Na primeira vez ela vem aberta. Na vertical, começa recolhida. Ao abrir, a barra
  pode ficar por cima do conteúdo ou empurrá-lo para o lado, como o sistema fizer. Não vale trocar a
  base da navegação só por isso.
- No regular, o avatar sai da toolbar da Home, porque já está na barra lateral. Com a barra
  recolhida, ele volta para o canto superior direito da Home.
- As rotas do `ReminderRouter` continuam funcionando, trocando a seção selecionada.

### Home no iPad

Validado em mockup (opção "C").

**Barra aberta (duas colunas):**

- Topo: logo, saudação e data à esquerda, `MonthPicker` à direita.
- Linha 1: card de saldo do mês com o gráfico maior e a escala dos dias (1, 10, 20, 31) à esquerda.
  À direita, três cards pequenos empilhados:
  - Falta receber: valor, "de \(previsto)" e selo de atrasadas;
  - Falta pagar: valor, "de \(previsto)" e selo de atrasadas;
  - Atrasadas: quantidade em `Theme.warning` e nomes resumidos. Tocar abre a seção Atrasadas.
- Linha 2: cards "Receitas" e "Despesas" lado a lado, com as ocorrências do mês na ordem das abas
  (pendentes e atrasadas primeiro, depois recebidas ou pagas). As pendentes têm um botão Receber ou
  Pagar na própria linha. Cada card tem "+ Nova" no cabeçalho, que abre o cadastro.

**Barra recolhida (três colunas):**

- Topo: logo, saudação e data, `MonthPicker` à direita.
- Linha de quatro números: Saldo do mês, Falta receber, Falta pagar e Atrasadas.
- Três colunas: Receitas, Despesas e "Saldo dia a dia" (o gráfico com a escala dos dias).

**iPad na vertical:** com a barra recolhida, empilha o card de saldo com gráfico, os três cards
pequenos lado a lado e as listas de Receitas e Despesas lado a lado.

**Comportamento:**

- O card de "Lançamentos" misturado sai da Home do iPad, porque as duas listas já mostram tudo. No
  iPhone ele continua, como na spec de despesas. (Decisão de quem desenhou, vista pelo dono no
  mockup.)
- O botão Receber abre a `ReceiptSheet` daquela ocorrência. O botão Pagar abre a sheet de despesa em
  "Marcar como paga". O resto da linha leva para a seção Receitas ou Despesas com aquela ocorrência
  selecionada no detalhe. (Decisão de quem desenhou.)
- A Home rola quando as listas passam da altura da tela.
- Na vertical, o resto da linha abre o detalhe em sheet por cima da Home, sem trocar de seção.
  (Decisão de quem desenhou.)
- Estados de carregamento, erro e vazio seguem os que existem hoje, um por card.

### Receitas e Despesas no iPad

- **Horizontal (regular com largura para duas colunas):** título da seção com o "+" à direita. À
  esquerda, a lista do mês como no iPhone (`MonthPicker`, card de resumo, Pendentes ou "A pagar",
  Recebidas ou Pagas, Cadastradas). À direita, o card de detalhe do item selecionado. A linha
  selecionada fica destacada com o accent em baixa opacidade.
- Ao entrar na seção, ou ao trocar de mês, a primeira pendente do mês vem selecionada. Sem pendente,
  a primeira da lista. Mês sem ocorrências mostra no painel o estado vazio que a lista já tem.
  (Decisão de quem desenhou.)
- **Vertical, ou horizontal sem largura para duas colunas:** só a lista, com a largura toda. Tocar
  abre o detalhe numa sheet por cima da lista.
- **Rotação** com item aberto: da horizontal para a vertical, o detalhe vira sheet aberta. Da
  vertical para a horizontal, a sheet fecha e o item fica selecionado no painel.
- Seção "Cadastradas": tocar continua abrindo o formulário de edição, como hoje. Linhas cadastradas
  não têm detalhe.

### Detalhe

Tela nova, a mesma em iPad e iPhone. No iPad fica no painel ou na sheet. No iPhone abre por push na
navegação, com botão de voltar.

**Receita:**

- Cabeçalho: tipo e regra de data ("Receita fixa · todo dia 5"), nome em destaque e botão Editar,
  que abre o `IncomeFormView` como hoje.
- Dois blocos:
  - pendente ou atrasada: "Previsto para \(mês)" com valor e "vence \(data) · daqui a N dias" ou
    "atrasada há N dias";
  - recebida: "Recebido em \(mês)" com o valor em verde e "em \(data)", com "como previsto" ou
    "previsto \(valor)" quando foi diferente;
  - ao lado: "Valor atual", com o valor vigente e "desde \(mês/ano)" da vigência. Receita por hora
    mostra o valor da hora.
- Botão principal, para pendente ou atrasada: "Marcar como recebida", que abre a `ReceiptSheet`.
- Para recebida: "Alterar recebimento", que abre a `ReceiptSheet`, e "Desmarcar recebimento"
  (destrutivo), que chama `unmarkReceived` direto, sem abrir a sheet.
- "Últimos meses": os três meses anteriores ao da ocorrência, com o valor recebido de cada um. Meses
  sem recebimento aparecem como "não recebida" e meses antes do início da receita ficam de fora.
  (Decisão de quem desenhou.)
- Receita avulsa: sem "Valor atual" e sem "Últimos meses".

**Despesa** (mesma estrutura, com as regras da spec de despesas):

- Cabeçalho: "Despesa fixa · vence dia \(d)", nome e Editar.
- Bloco do valor: valor da ocorrência com a origem ("estimado pela média de jul, ago e set",
  "estimado" ou "conta lançada"), ou "Pago em \(mês)" com valor e data.
- Bloco ao lado: vencimento ("20/10 · daqui a 3 dias" ou "atrasada há N dias").
- Ações, para não paga: "Marcar como paga" como botão principal e "Lançar valor da conta" como
  secundário. Cada uma abre a sheet de despesa no modo correspondente. Com a conta já lançada, o
  secundário vira "Alterar conta lançada".
- Para paga: "Alterar pagamento", que abre a sheet em "Marcar como paga", e "Desmarcar pagamento"
  (destrutivo), direto.
- "Últimos meses": os três meses anteriores com o valor pago, com as mesmas regras da receita para
  mês sem pagamento e mês antes do início.
- Onde o mockup diz "Pagar" no detalhe de despesa, vale o texto desta spec ("Marcar como paga").

Depois de salvar numa sheet aberta pelo detalhe, a sheet fecha e o detalhe mostra os dados novos.

### iPhone

- Tocar numa ocorrência, em Receitas, Despesas e Atrasadas, abre o detalhe por push. Antes, abria a
  sheet. Para receber, o fluxo fica: linha, "Marcar como recebida", salvar. Um toque a mais, aceito
  pelo dono em mockup.
- O menu de contexto da linha ("Editar receita") continua.
- O resto do iPhone fica como está.

### Atrasadas no iPad

Mesmo formato de Receitas e Despesas: lista à esquerda, com o card de topo e as seções Receitas e
Despesas da spec de despesas, e detalhe à direita. Tocar numa linha abre o detalhe. No detalhe da
despesa, o botão principal já é "Marcar como paga". (Decisão de quem desenhou, sem mockup.)

### Visual

- Mesma identidade de hoje: `AppBackground`, cards de vidro com raio 26, `MonthPicker` de vidro,
  cores do `Theme`, tipografia do sistema e valores com `monospacedDigit()`.
- A barra lateral e o botão flutuante usam o vidro do sistema (`glassEffect`).
- Sem ícones nas linhas, como define a spec de despesas.
- `readableWidth(contentWidth)` deixa de valer nas telas do layout regular. No compacto continua.

## Como validar

- Testes do que for lógica pura: escolha da ocorrência selecionada por padrão (primeira pendente,
  senão a primeira, senão nenhuma); montagem dos "Últimos meses" (receita que começou há menos de três
  meses, mês sem recebimento, receita avulsa); contadores da barra lateral.
- Previews ou snapshots, se o projeto já tiver o padrão, das telas regular e compacta.
- Manual no simulador:
  - iPad Pro 11" e 13", na horizontal e na vertical: Home com a barra aberta e recolhida, Receitas,
    Despesas e Atrasadas com o detalhe; botão de abrir a barra embaixo à esquerda; o botão do sistema
    não aparece;
  - girar com um item aberto e conferir que o mês e o item continuam;
  - iPad em Split View com 1/3 da tela: layout do iPhone, sem cortes;
  - iPhone: tocar numa receita abre o detalhe; "Marcar como recebida" abre a sheet; ao salvar, o
    detalhe mostra a receita como recebida; "Desmarcar recebimento" volta a pendente;
  - tocar num aviso de atraso e de "vence hoje" com o app no iPad e conferir que a seção certa abre;
  - modo escuro nas telas novas.

## Deixado para quem constrói

- Como implementar a barra (estilo do `TabView`, `NavigationSplitView` ou outro), desde que cumpra
  "Navegação". Se o botão próprio embaixo não for viável, falar com o dono antes.
- Pontos de corte de largura, espaçamentos e tamanhos finos, guiados pelo mockup.
- Nomes de tipos e arquivos, e onde fica o estado da seleção e da barra.
- Textos de ajuda e dos estados vazios do detalhe.
- Se o detalhe de receita e o de despesa compartilham componentes.
