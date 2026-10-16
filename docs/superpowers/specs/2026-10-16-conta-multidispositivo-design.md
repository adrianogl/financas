# Conta no Supabase para usar o Finanças em vários aparelhos

Data: 2026-10-16

## Por quê

O Finanças é um app de controle financeiro pessoal, de um usuário só (o dono). Hoje tudo vive no
aparelho: nome em `UserDefaults`, PIN no Keychain, home com dados de exemplo. O dono quer usar a
mesma conta em qualquer aparelho, inclusive Android e web no futuro. Isso exige uma conta central e
um backend.

## Objetivo desta etapa

- Conta com e-mail e senha no Supabase (Auth).
- O primeiro acesso em cada aparelho pede a conta. Depois disso, o app abre com o desbloqueio
  local que já existe (biometria ou PIN), sem pedir a senha de novo.
- O nome do usuário vem da conta e aparece em qualquer aparelho.

## Fora do escopo

- Dados financeiros reais e tabelas de domínio. A home segue com dados de exemplo.
- Funcionamento offline além do que o SDK já faz com a sessão guardada.
- Login com Google, Apple ou link mágico. Só e-mail e senha.
- App Android ou web. A escolha do Supabase é para não fechar essa porta.
- Exclusão de conta pelo app (só seria obrigatória para publicar na App Store).

## Anti-objetivos

- Não pedir e-mail e senha toda vez que o app abre.
- Não sincronizar o PIN entre aparelhos: um PIN vazado não pode abrir a conta em outro aparelho.
- Não guardar a chave secreta (service role) do Supabase no app.

## Estado atual (para quem vai construir)

Projeto iOS em SwiftUI, gerado pelo XcodeGen (`project.yml`), mínimo iOS 26, Swift 6, Liquid Glass.
Arquivos relevantes:

- `Financas/Lock/LockManager.swift`: máquina de estados do desbloqueio (`LockPhase`: `locked`,
  `biometric`, `pin`, `unlocked`), PIN de 4 dígitos, tempo de espera depois de erros, rebloqueio após
  30 s em segundo plano, timeout de 10 s na biometria, suporte a Face ID, Touch ID e aparelho sem
  biometria.
- `Financas/Lock/KeychainPINStore.swift`: hash do PIN com salt no Keychain; apaga o PIN de uma
  instalação anterior no primeiro uso.
- `Financas/Setup/SetupView.swift`: primeiro uso hoje pede nome (salvo em `@AppStorage` com
  `ProfileConstants.nameKey`) e depois cria o PIN.
- `Financas/RootView.swift`: escolhe entre cadastro, home e as telas de bloqueio.
- Testes em `FinancasTests` (Swift Testing), com fakes para `Authenticator` e `PINStore`.

Convenções do dono: sem comentários no código; um tipo por arquivo; constantes em arquivo próprio
(`*Constants.swift`); textos da interface em português.

## Decisões

### Backend

Supabase, plano gratuito, projeto criado pelo dono na conta dele. O plano gratuito pausa projetos
com pouca atividade em 7 dias; uso diário evita a pausa. Nenhuma tabela nova nesta etapa.

SDK: `supabase-swift` v3 via Swift Package Manager (declarado no `project.yml`). A sessão fica no
Keychain pelo armazenamento padrão do SDK, que renova o token sozinho.

### Configuração

URL do projeto e chave publicável ficam num `Config/Secrets.xcconfig` fora do git, com um
`Config/Secrets.example.xcconfig` versionado. O `project.yml` referencia o xcconfig, e os valores
chegam ao app pelo `Info.plist` (`SupabaseURL`, `SupabaseKey`). Sem o arquivo, o build falha com
mensagem clara. A chave publicável não é segredo, mas fica fora do git para o repositório poder ser
público sem expor o projeto.

### Fluxo ao abrir o app

1. Sem sessão da conta no aparelho: tela de conta (entrar ou criar conta). Nada de biometria ou PIN
   antes disso.
2. Logo depois de entrar com e-mail e senha (ou de redefinir a senha), sem PIN no aparelho: cria o
   PIN, sem pedir nome (o nome vem da conta) e sem biometria, porque a senha acabou de provar a
   identidade. Essa dispensa vale só nesse momento, nunca para uma sessão restaurada do Keychain.
3. Com sessão e PIN: fluxo atual de desbloqueio, sem mudança.

Uma sessão restaurada sem PIN não pode acontecer: numa instalação nova o app apaga a sessão do SDK
junto com o PIN (mesmo marcador de instalação do `KeychainPINStore`), e "Sair da conta" apaga os
dois. Se mesmo assim ocorrer, o app trata como sem sessão: faz `signOut` local e mostra a tela de
conta. (Decisão de quem desenhou: evita que alguém com o iPhone desbloqueado reinstale o app, crie
um PIN e veja a conta.)

### Validação da sessão

O app abre na hora com a sessão guardada (evento `.initialSession` do SDK v3) e deixa o SDK renovar
o token em segundo plano. Só manda para a tela de conta, apagando o PIN local, quando o servidor
recusa a sessão (refresh token inválido ou revogado, usuário removido): eventos `.signedOut` ou erro
de autenticação do Supabase. Erro de rede ou falta de internet nunca tira o usuário do app nem apaga
o PIN. (Decisão de quem desenhou.)

### Tela de conta

- Dois modos na mesma tela: "Entrar" e "Criar conta".
- Criar conta pede nome, e-mail e senha (mínimo de 8 caracteres). O nome vai para o
  `user_metadata.name` do Supabase.
- Confirmação de e-mail ligada (padrão do Supabase). Depois de criar a conta, a tela mostra
  "Confirme seu e-mail" com o endereço e um botão "Já confirmei", que tenta entrar com o e-mail e a
  senha digitados.
- "Esqueci minha senha" envia o e-mail de redefinição do Supabase. O link abre o app por um esquema
  próprio (`financas://auth-callback`), e o app mostra a tela de nova senha. Esquema de URL próprio
  funciona com a conta gratuita de desenvolvedor.
- O link de redefinição usa o PKCE padrão do SDK, então só funciona no aparelho que pediu. Se for
  aberto em outro lugar, o usuário pede de novo (aceito pelo dono). A tela "Esqueci minha senha"
  avisa: "Abra o link neste aparelho".
- Depois de salvar a nova senha, o app chama `signOut(scope: .others)` para derrubar os outros
  aparelhos (pedido do dono) e segue logado neste: vai para a criação do PIN se não houver PIN, ou
  direto para a home se houver.
- Erros em português e específicos: senha incorreta, e-mail ainda não confirmado, sem internet,
  e-mail já cadastrado.
- Visual igual ao resto do app: fundo `AppBackground`, campos e botões com Liquid Glass, `AppMark`
  no topo.

### Nome do usuário

Lido de `user_metadata.name` da sessão. A home usa esse valor no cumprimento. A chave
`ProfileConstants.nameKey` e o passo de nome do `SetupView` deixam de existir.

### Quem já tem o app instalado

Só o dono tem o app hoje. Na atualização, o app trata a primeira abertura como instalação nova:
descarta o nome do `@AppStorage`, o PIN e os contadores, e começa pela tela de conta. (Decisão de
quem desenhou.)

### PIN por aparelho

O PIN continua local, como hoje. "Sair da conta" apaga sessão, PIN e contadores de tentativa
daquele aparelho.

### Sair da conta

Botão "Sair da conta" num menu da home (ao lado de "Bloquear"), com confirmação na própria tela
(o app não usa `alert`). Chama `auth.signOut()` e volta para a tela de conta. "Bloquear" continua
só travando o app, sem disparar a biometria.

### Arquitetura

- Novo `AccountManager` (`@MainActor @Observable`), dono do estado da conta: `signedOut`,
  `awaitingConfirmation(email)`, `signedIn(name)`. Fala com o Supabase por um protocolo
  (`AccountService`) para poder ser testado com fake, como o `Authenticator`.
- `RootView` passa a decidir primeiro pela conta e só depois pelo `LockManager`.
- `LockManager` ganha um jeito de começar o primeiro uso sem exigir biometria quando a conta acabou
  de ser autenticada, e de apagar o PIN ao sair da conta.

### Configuração no painel do Supabase (feita pelo dono, com guia)

- Criar o projeto.
- Auth > URL Configuration: adicionar `financas://auth-callback` e `financas://auth-callback/recovery` às URLs de redirecionamento.
- Copiar URL e chave publicável para o `Secrets.xcconfig`.

## Como validar

- Testes unitários do `AccountManager` com fake do `AccountService`: criar conta, entrar, e-mail não
  confirmado, senha errada, sessão recusada pelo servidor (vai para a conta e apaga o PIN), erro de
  rede ao renovar (continua logado e mantém o PIN), nova senha derruba os outros aparelhos, sair da
  conta.
- Testes do `LockManager` para os pontos novos: PIN criado sem biometria logo depois do login, PIN
  apagado ao sair.
- Teste manual no simulador e no iPhone contra o projeto real: criar conta, confirmar e-mail, entrar,
  criar PIN, fechar e abrir (só biometria ou PIN), sair, entrar de novo no segundo simulador com a
  mesma conta e ver o mesmo nome.

## Deixado para quem constrói

- Layout fino da tela de conta, dentro do visual já definido.
- Como estruturar o fake e os testes.
- Mensagens exatas de erro, desde que em português e específicas.
