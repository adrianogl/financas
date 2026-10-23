import { assertEquals } from "jsr:@std/assert@1"
import { accountRow, brandLabel, connectionStatus, institutionName, syncWindow, transactionRow } from "./cardRows.ts"
import type { PluggyAccount, PluggyTransaction } from "./pluggyTypes.ts"

const base: PluggyTransaction = {
  id: "tx1",
  description: "MERCADO",
  amount: 50,
  currencyCode: "BRL",
  date: "2026-10-20T00:00:00.000Z",
  type: "DEBIT",
  status: "POSTED",
}

const acc: PluggyAccount = { id: "a1", name: "BANDEIRADO", number: "4526", type: "CREDIT" }

Deno.test("transactionRow usa o valor na moeda do cartão", () => {
  const row = transactionRow({ ...base, amount: 20, amountInAccountCurrency: 103.4, currencyCode: "USD" }, "acc")
  assertEquals(row.amount, 103.4)
})

Deno.test("transactionRow grava valor absoluto, tipo, pendência e parcela", () => {
  const row = transactionRow({
    ...base,
    amount: -900,
    type: "CREDIT",
    status: "PENDING",
    creditCardMetadata: { installmentNumber: 3, totalInstallments: 4, purchaseDate: "2026-06-27T08:01:00.000Z" },
  }, "acc")
  assertEquals(
    [row.amount, row.type, row.is_pending, row.installment_number, row.total_installments, row.purchase_date],
    [900, "CREDIT", true, 3, 4, "2026-06-27"],
  )
  assertEquals(row.date, base.date.slice(0, 10))
})

Deno.test("transactionRow sem metadata deixa parcela e compra nulas", () => {
  const row = transactionRow(base, "acc")
  assertEquals(
    [row.id, row.card_account_id, row.installment_number, row.total_installments, row.purchase_date, row.is_pending],
    ["tx1", "acc", null, null, null, false],
  )
})

Deno.test("accountRow gera apelido com nome e final, e preserva apelido existente", () => {
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO      ", number: "4526" }, "c", null).nickname, "BANDEIRADO ····4526")
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO", number: "4526" }, "c", null, "C6").nickname, "C6")
})

Deno.test("accountRow aparra o nome e grava o final", () => {
  const row = accountRow({ ...acc, name: "BANDEIRADO  " }, "c", null)
  assertEquals([row.name, row.last_digits, row.pluggy_account_id, row.connection_id], ["BANDEIRADO", "4526", "a1", "c"])
})

Deno.test("connectionStatus", () => {
  assertEquals(connectionStatus({ status: "LOGIN_ERROR" }), "needs_reconnect")
  assertEquals(connectionStatus({ status: "WAITING_USER_INPUT" }), "needs_reconnect")
  assertEquals(connectionStatus({ status: "OUTDATED" }), "error")
  assertEquals(connectionStatus({ status: "UPDATED" }), "active")
})

Deno.test("syncWindow: 12 meses na primeira vez, 7 dias antes do último sync depois", () => {
  assertEquals(syncWindow(null, "2026-10-22"), { from: "2025-10-22", to: "2026-10-22" })
  assertEquals(syncWindow("2026-10-21T06:10:00Z", "2026-10-22"), { from: "2026-10-14", to: "2026-10-22" })
})

const bank = (transferNumber: string | null, name = "C6 BANK"): PluggyAccount => ({
  id: "b1",
  name,
  number: "0001",
  type: "BANK",
  bankData: { transferNumber },
})

Deno.test("institutionName deriva o banco do código COMPE do transferNumber", () => {
  assertEquals(institutionName([acc, bank("336/0001/00040367-9")]), "C6")
  assertEquals(institutionName([bank("104/0001/1-1", "CAIXA"), bank("336/0001/2-2")]), "Caixa")
  assertEquals(institutionName([bank("260/0001/1-1", "Nu Pagamentos S.A.")]), "Nubank")
})

Deno.test("institutionName usa o nome da conta BANK para código desconhecido, ignora BANK sem transferNumber e devolve null sem BANK", () => {
  assertEquals(institutionName([bank("999/0001/1-1", "  Banco Foo  ")]), "Banco Foo")
  assertEquals(institutionName([bank(null), bank("077/0001/1-1", "BANCO INTER")]), "Inter")
  assertEquals(institutionName([bank(null)]), null)
  assertEquals(institutionName([acc]), null)
  assertEquals(institutionName([]), null)
})

Deno.test("brandLabel junta bandeira e nível em title case", () => {
  assertEquals(brandLabel({ ...acc, creditData: { brand: "MASTERCARD", level: "BLACK" } }), "Mastercard Black")
  assertEquals(brandLabel({ ...acc, creditData: { brand: "VISA", level: "PLATINUM" } }), "Visa Platinum")
  assertEquals(brandLabel({ ...acc, creditData: { brand: "VISA", level: null } }), "Visa")
  assertEquals(brandLabel({ ...acc, creditData: { brand: null, level: "GOLD" } }), "Gold")
  assertEquals(brandLabel({ ...acc, creditData: {} }), null)
  assertEquals(brandLabel(acc), null)
})

Deno.test("accountRow usa o banco como apelido padrão e grava brand_label", () => {
  const row = accountRow({ ...acc, creditData: { brand: "MASTERCARD", level: "BLACK" } }, "c", "C6")
  assertEquals([row.nickname, row.brand_label], ["C6", "Mastercard Black"])
  assertEquals(accountRow(acc, "c", null).nickname, "BANDEIRADO ····4526")
  assertEquals(accountRow(acc, "c", null).brand_label, null)
})

Deno.test("accountRow troca o apelido padrão antigo pelo novo e preserva o apelido do usuário", () => {
  assertEquals(accountRow(acc, "c", "C6", "BANDEIRADO ····4526").nickname, "C6")
  assertEquals(accountRow(acc, "c", null, "BANDEIRADO ····4526").nickname, "BANDEIRADO ····4526")
  assertEquals(accountRow(acc, "c", "C6", "Meu cartão").nickname, "Meu cartão")
})
