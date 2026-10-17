# Finanças

App de finanças pessoais para iPhone e iPad, feito em SwiftUI. O foco hoje são as receitas: cadastrar
as fixas, as por hora e as avulsas, marcar o que caiu e ver quanto falta receber no mês.

## O que o app faz

- Cadastro de receitas fixas, por hora e avulsas, com valores que mudam a partir de um mês.
- Data prevista no próximo dia útil, considerando fins de semana e feriados bancários nacionais.
- Home com o mês escolhido: saldo do mês, quanto falta receber e lançamentos.
- Aba Atrasadas com o que passou da data sem ser marcado como recebido.
- Avisos locais às 8h e às 19h enquanto houver receita atrasada, e às 8h no dia em que uma receita
  deve cair.
- Conta no Supabase, com os dados iguais em todos os aparelhos, e foto do avatar.
- Trava com Face ID, Touch ID ou PIN de 4 dígitos.

## Stack

- iOS 26, Swift 6, SwiftUI
- [Supabase](https://supabase.com) (Auth, Postgres com RLS e Storage) pelo `supabase-swift`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) para gerar o projeto a partir do `project.yml`
- Swift Testing

## Como rodar

1. Crie um projeto no Supabase e aplique as migrations de `supabase/migrations`.
2. Em Authentication > URL Configuration, adicione `financas://auth-callback` e
   `financas://auth-callback/recovery` às Redirect URLs. Os e-mails de confirmação e de
   redefinição de senha estão em `supabase/templates`.
3. Copie `Config/Secrets.example.xcconfig` para `Config/Secrets.xcconfig` e preencha com a URL do
   projeto e a chave publicável. Esse arquivo fica fora do git. Nunca coloque a chave service role
   no app.
4. Troque o `DEVELOPMENT_TEAM` do `project.yml` pelo seu Team ID da Apple.
5. Gere o projeto e abra no Xcode:

   ```sh
   xcodegen generate
   open Financas.xcodeproj
   ```

## Testes

```sh
xcodebuild test -scheme Financas -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

## Documentação

As decisões de cada funcionalidade estão em `docs/superpowers/specs`, e os planos de implementação
em `docs/superpowers/plans`.

## Licença

[MIT](LICENSE)
