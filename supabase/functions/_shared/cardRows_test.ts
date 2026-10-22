import { assertEquals } from "jsr:@std/assert@1"
import { accountRow, connectionStatus, syncWindow, transactionRow } from "./cardRows.ts"
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
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO      ", number: "4526" }, "c").nickname, "BANDEIRADO ····4526")
  assertEquals(accountRow({ ...acc, name: "BANDEIRADO", number: "4526" }, "c", "C6").nickname, "C6")
})

Deno.test("accountRow aparra o nome e grava o final", () => {
  const row = accountRow({ ...acc, name: "BANDEIRADO  " }, "c")
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
