# Despesas com partes e gasto do mês

Data: 2026-10-18

Mockup validado com o dono: `docs/superpowers/mockups/2026-10-18-partes-e-gasto-do-mes.html`.

## Por quê

Algumas despesas não cabem num valor só por mês.

- O boleto do condomínio junta a taxa, a água e o gás. O dono paga uma vez, mas quer ver quanto foi de
  água e de gás mês a mês, para saber se subiu.
- O abastecimento é uma despesa só, com várias saídas ao longo do mês, pagas na hora. O dono não quer
  cadastrar uma despesa para cada abastecida, que polui a lista, nem trocar o valor total a cada vez,
  que perde o detalhe.

O app serve para controle macro do mês, não para contar centavo. Lançar a semana inteira de
abastecimento de uma vez é um uso esperado.

## Objetivo

- Conta com vencimento pode ter **partes**: cada parte tem nome, Fixo ou Varia e valor. O valor da
  conta é a soma das partes. O detalhe mostra cada parte e o histórico mês a mês por parte.
- Novo tipo de despesa, **gasto do mês**: sem vencimento, com um valor previsto por mês e lançamentos
  rápidos (valor e data) que já contam como pagos.

## Fora do escopo

- Partes em gasto do mês.
- Categorias, orçamento por categoria, relatórios.
- Trocar o tipo de uma despesa já cadastrada (conta com vencimento ↔ gasto do mês).
- Avisos para gasto do mês, inclusive quando passa do previsto.
- Média para o previsto do gasto do mês.

## Anti-objetivos

- Mudar o uso de uma despesa sem partes, como internet e luz: ela continua exatamente como hoje.
- Exigir que o dono lance cada parte ou cada abastecida para o mês fechar. Com partes, os campos já vêm
  com o estimado. No gasto do mês, os lançamentos são opcionais e podem juntar vários dias.
- Gasto do mês aparecendo como atrasado ou gerando aviso.

## Estado atual (para quem vai construir)

- Despesa: `Expense` (nome, início, fim, `isFixed`), vigências em `ExpenseTerm` (valor estimado, dia de
  vencimento, `averageFrom`) e registro do mês em `ExpenseBill` (conta lançada e pagamento).
  Ocorrências são calculadas em `ExpenseSchedule`. Estimado: `ExpenseEstimate` (`manual`, `average`,
  `fixed`).
- Spec de origem: `docs/superpowers/specs/2026-10-17-despesas-fixas-design.md`. Regras de vencimento,
  status, média, aba Despesas, Home, Atrasadas e avisos continuam valendo onde este documento não diz
  outra coisa.
- Detalhe e lista com detalhe ao lado no iPad: `docs/superpowers/specs/2026-10-17-layout-ipad-design.md`.

## Decisões

### Tipo da despesa

O cadastro de uma despesa nova começa com um seletor no topo: **Conta com vencimento** | **Gasto do
mês**. Padrão: Conta com vencimento. Ao editar, o seletor não aparece, porque o tipo não muda depois de
criado. (Decisão de quem desenhou: trocar o tipo exigiria converter meses já registrados.)

As despesas que já existem são contas com vencimento.

### Conta com partes

#### Cadastro

- Seção "Partes" no formulário da conta com vencimento, com uma linha por parte (nome, Fixo/Varia,
  valor) e "Adicionar parte". Cada parte pode ser removida.
- Sem partes, o formulário é o de hoje, com o seletor Fixo/Varia e o valor da despesa.
- Com uma ou mais partes, o seletor Fixo/Varia e o campo de valor da despesa somem. O previsto da
  despesa é a soma das partes.
- Nome da parte é obrigatório. Valor maior que zero.
- A ordem das partes é a ordem de cadastro. (Decisão de quem desenhou: reordenar fica fora.)
- Uma parte nova começa como Varia. (Decisão de quem desenhou: parte costuma existir porque varia.)

#### Mudanças no tempo

Seguem a regra das vigências de hoje: valem do mês atual em diante e não mudam meses anteriores.

Exceção: se o mês atual já tem conta lançada ou pagamento, qualquer mudança no conjunto de partes ou
nos valores delas vale do mês seguinte em diante. O mês atual fica com as partes que tinha quando foi
registrado. (Decisão de quem desenhou: sem isso, uma parte nova entraria num mês já pago e a soma das
partes deixaria de fechar com o que foi pago.) A mesma regra vale para "mês atual" em todos os itens
abaixo.

- Editar o valor de uma parte cria uma vigência para ela e reinicia a contagem da média daquela parte,
  como o valor estimado de hoje.
- Trocar Fixo/Varia de uma parte vale do mês atual em diante.
- Remover uma parte encerra a parte no mês anterior ao atual. Os meses já registrados continuam com o
  valor dela no histórico.
- Adicionar a primeira parte a uma despesa que já existe vale do mês atual em diante. Meses anteriores
  continuam com um valor só e aparecem no histórico só com o total.
- Remover todas as partes volta a despesa a ter um valor só, do mês atual em diante, como Varia. O
  valor da despesa passa a ser a soma dos valores cadastrados (vigentes) das partes no último mês em
  que elas valiam, e a contagem da média recomeça como numa edição de valor. (Decisão de quem desenhou.)
- Enquanto a despesa tem partes, o Fixo/Varia da despesa (`isFixed`) é ignorado. Valem só os de cada
  parte. A sheet abre em "Marcar como paga" quando todas as partes são Fixo, e em "Lançar conta" quando
  alguma é Varia e o mês ainda não tem conta lançada. (Decisão de quem desenhou.)
- O nome da parte é único entre as partes ativas da despesa. Adicionar uma parte com o nome de uma
  parte removida reativa a parte antiga, com o histórico e a média dela. Renomear uma parte troca o
  nome em todo o histórico. (Decisão de quem desenhou.)

#### Ciclo de cada parte

Pedido do dono depois do mockup: as partes podem vencer em dias diferentes e ser pagas em dias
diferentes. Cada parte tem o próprio ciclo dentro da despesa.

- No cadastro, cada parte tem um dia de vencimento opcional. Vazio, usa o dia da despesa. O dia segue
  a regra de vigência das outras mudanças da parte.
- No mês M, cada parte tem vencimento, conta lançada (valor e vencimento informado) e pagamento (valor
  e data) próprios. O vencimento calculado segue a regra de hoje: dia vigente, próximo dia útil.
- Status de cada parte: paga (tem pagamento), atrasada (sem pagamento, vencimento antes de hoje),
  pendente (o resto).

#### Valor de cada parte no mês

Para a parte P no mês M, na ordem:

1. Pago: o valor pago de P em M.
2. Conta lançada: o valor da conta de P em M.
3. Fixo: o valor vigente de P em M.
4. Varia, com pelo menos 3 meses pagos de P antes de M, contando a partir da última edição do valor de
   P: média dos 3 mais recentes, arredondada para centavos. Mesma regra de hoje, por parte.
5. Varia, sem isso: o valor vigente de P em M.

#### A despesa com partes no mês

- Valor: soma das partes. Falta: soma das partes sem pagamento.
- Status: paga quando todas as partes estão pagas; atrasada quando alguma parte está atrasada;
  pendente no resto. Com alguma parte paga e outra em aberto, a linha mostra o selo
  "parcialmente paga" (o selo "atrasada" tem prioridade).
- Vencimento da linha: o menor vencimento entre as partes em aberto; paga, o maior vencimento.
- Atrasada de mês anterior continua aparecendo no mês atual até todas as partes serem pagas, como hoje.

#### Lançar conta e marcar como paga

Dois jeitos, porque às vezes o boleto vem junto e às vezes cada parte é paga num dia:

- **Conta inteira** (botões "Marcar como paga" e "Lançar valor da conta" do detalhe e o toque na linha
  da lista): a sheet de hoje com um campo por parte em aberto e o total.
  - Lançar conta: valor de cada parte e um vencimento único, que vale para todas as partes lançadas.
  - Marcar como paga: valor de cada parte em aberto e uma data única. Marca como pagas todas as partes
    que estavam em aberto. Partes já pagas não aparecem nos campos.
- **Uma parte** (toque na parte no detalhe): a mesma sheet, só com a parte, no formato de uma despesa
  sem partes: "Lançar conta" com valor e vencimento, "Marcar como paga" com valor e data,
  "Remover conta" e "Desmarcar pagamento".
- O pagamento de cada parte guarda o próprio valor e a própria data.

#### Lista e detalhe

- Na aba Despesas, a conta com partes é uma linha só, com o total. A legenda junta o vencimento da linha
  e os nomes das partes: "26/10 · taxa, água e gás". Selos: "atrasada", senão "parcialmente paga",
  senão como hoje. Fica em "A pagar" até todas as partes estarem pagas.
- Detalhe:
  - Cabeçalho "Todo dia 26 · 3 partes".
  - Card do mês com o total e uma linha por parte: nome, valor e situação ("vence 10/10", "atrasada" ou
    "paga em 12/10"). A parte Varia mostra também a diferença para o mês anterior, "▲ R$ 30 vs.
    setembro" na cor de alerta quando subiu e "▼ R$ 5 vs. setembro" na cor positiva quando desceu, só
    quando os dois meses têm valor pago ou lançado para a parte. Tocar na parte abre a sheet da parte.
  - "Últimos meses" vira uma tabela: uma linha por mês, uma coluna por parte e a coluna Total. A célula
    da parte Varia que subiu em relação ao mês anterior fica na cor de alerta. Mês sem valor para a
    parte mostra "—".
  - Ações: Marcar como paga e Lançar valor da conta (conta inteira), Editar. Com todas pagas, como hoje.
- No iPad, o mesmo detalhe aparece no painel ao lado da lista ou na sheet, como os outros detalhes.

#### Atrasadas, avisos e Home

- Aba Atrasadas: cada parte atrasada é uma linha, "Condomínio · água", com o vencimento e o valor da
  parte. Tocar abre a sheet da parte, em "Marcar como paga".
- Avisos de vence hoje e de atraso: cada parte conta como uma conta, com o título "Condomínio · água" e
  o valor da parte.
- "Falta pagar" (aba e Home) soma a falta das partes. Badge de atrasadas conta partes atrasadas.
- Home: cada pagamento de parte é uma saída na sua data e um lançamento "Condomínio · água".

### Gasto do mês

#### Cadastro

- Campos: nome, previsto por mês (maior que zero), mês de início e mês de fim opcional. Sem dia de
  vencimento.
- Texto de ajuda: "Gasto do mês não tem vencimento nem aviso. Você adiciona os gastos ao longo do mês,
  e eles já contam como pagos."
- Editar o previsto vale do mês atual em diante, como as vigências de hoje. Encerrar e excluir como as
  outras despesas. Excluir apaga também os lançamentos, com a confirmação de hoje.

#### Lançamentos

- "Adicionar gasto" abre uma sheet curta com valor (maior que zero) e data. Botão "Adicionar".
- A data padrão é hoje. Vendo um mês passado, a data padrão é o último dia daquele mês. Não aceita
  data futura, data antes do início ou depois do fim da despesa.
- O lançamento pertence ao mês da sua data. Mudar a data para outro mês move o lançamento para aquele
  mês.
- Tocar num lançamento abre a mesma sheet para editar. Arrastar a linha para o lado apaga, sem
  confirmação. (Decisão de quem desenhou: é um registro pequeno, fácil de lançar de novo.)

#### Valores do mês

- Gasto: soma dos lançamentos do mês.
- Previsto: o previsto vigente no mês.
- Falta: previsto menos gasto, nunca negativo. Vale só para o mês atual e meses futuros. Mês passado
  não tem falta: o que não foi gasto não é dívida.
- Passou do previsto: o valor gasto e a barra ficam na cor de alerta, e a legenda diz "R$ 50,00 acima
  do previsto".

#### Lista e detalhe

- Na aba Despesas, o gasto do mês fica numa seção própria, **"Gastos do mês"**, acima de "A pagar".
  Cada linha mostra o nome, "gasto do mês · N lançamentos", uma barra de gasto sobre previsto e "R$
  420,00 de R$ 600,00". Sem selo de status. (Decisão de quem desenhou: misturar com "A pagar" e
  "Pagas" faria a linha mudar de seção sem nunca ser paga.)
- Na seção "Cadastradas", a linha mostra "Gasto do mês · previsto R$ 600,00".
- Detalhe:
  - Cabeçalho "Gasto do mês · previsto R$ 600".
  - Card "Gasto em outubro" com o valor, "de R$ 600,00", a barra e "Faltam R$ 180,00 do previsto".
  - Botão "Adicionar gasto".
  - "Lançamentos de outubro": um por linha, data e valor, do mais recente para o mais antigo. Estado
    vazio curto quando não há lançamento.
  - "Últimos meses": gráfico de barras com o gasto total dos últimos 6 meses em que a despesa existia,
    com o mês selecionado destacado. (Decisão de quem desenhou: o mockup mostra 4 só por espaço.)
  - Sem vencimento, sem atraso, sem "Marcar como paga" e sem "Lançar conta".

#### Resumos, Home, Atrasadas e avisos

- Card de resumo da aba Despesas: Pago soma os lançamentos do mês. Falta pagar soma a falta do gasto
  do mês (regra acima). Previsto continua sendo Pago + Falta pagar.
- Home, "Falta pagar": soma a falta do gasto do mês. A barra de progresso usa os mesmos números. A
  "próxima conta" ignora gasto do mês, porque não tem vencimento.
- Home, saldo do mês: cada lançamento é uma saída na sua data, e o gráfico desce nesse dia.
- Home, lançamentos do mês: cada lançamento aparece como um pagamento, com o nome da despesa e a
  legenda "Despesa · \(dia)".
- Aba Atrasadas e avisos: gasto do mês nunca aparece.

### Banco

Mudanças no Supabase, com RLS igual às tabelas de despesas de hoje (só o próprio `user_id`, e filhos
só de despesa do próprio dono). O que precisa caber:

- o tipo da despesa (conta com vencimento ou gasto do mês), com as existentes como conta com
  vencimento;
- as partes da despesa: nome, ordem, mês de início e mês de fim;
- as vigências de cada parte: valor, Fixo/Varia, dia de vencimento opcional, o mês a partir do qual
  valem, e desde quando contar a média;
- o registro do mês de cada parte: conta lançada (valor, vencimento informado) e pagamento (data,
  valor), como o registro do mês de uma despesa;
- o previsto do gasto do mês, com vigência;
- os lançamentos do gasto do mês: valor e data.

A migration é aplicada só com o OK do dono, depois da revisão.

### Arquitetura

- O cálculo continua puro e testável em `ExpenseSchedule` ou em tipos ao lado dele: valor de cada
  parte no mês, média por parte, diferença para o mês anterior, valores do gasto do mês.
- O resumo do mês da aba Despesas e o da Home passam a receber os gastos do mês.
- O store de despesas carrega partes, vigências de partes e lançamentos junto com o que já carrega, num
  snapshot só.

## Como validar

- Testes do cálculo:
  - conta sem partes continua igual (os testes de hoje passam sem mudança);
  - valor de cada parte: pago, lançado, fixo, média com 3 meses pagos da parte, vigente;
  - editar o valor de uma parte reinicia a média só daquela parte;
  - total da ocorrência é a soma das partes; status e vencimento não mudam;
  - adicionar a primeira parte, remover uma parte e remover todas valem do mês atual em diante;
  - diferença para o mês anterior: subiu, desceu, sem valor no mês anterior;
  - gasto do mês: gasto, falta, mês passado sem falta, acima do previsto;
  - lançamento conta no mês da sua data;
  - resumo da aba e da Home com gasto do mês;
  - gasto do mês fora de Atrasadas e dos avisos.
- Testes do store com fake: salvar despesa com partes, lançar e pagar com partes, adicionar, editar e
  apagar lançamento; erro de rede mantém o estado anterior.
- Migration: outro usuário não lê nem altera partes e lançamentos; advisors sem aviso novo.
- Manual no iPhone e no iPad:
  - cadastrar o condomínio com Taxa (fixo), Água e Gás (varia); lançar a conta de outubro; pagar;
    conferir o detalhe e a tabela;
  - cadastrar o abastecimento com previsto R$ 600; adicionar três gastos; conferir a barra, a aba, o
    resumo e a Home; passar do previsto;
  - conferir que internet e luz continuam como antes.

## Deixado para quem constrói

- Esquema exato das tabelas e nomes da migration, desde que cubra o que está em "Banco".
- Nomes de tipos e arquivos.
- Textos de estados vazios e de validação.
- Como reaproveitar o detalhe e a sheet de hoje para as partes.
