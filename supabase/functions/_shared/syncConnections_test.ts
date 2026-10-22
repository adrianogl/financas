import { assert, assertEquals } from "jsr:@std/assert@1"
import { fakeAdmin } from "./fakeAdmin.ts"
import type { PluggyClient } from "./pluggy.ts"
import { syncConnections } from "./syncConnections.ts"

Deno.test("falha numa conexão grava last_error e não impede as outras", async () => {
  const tables = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
      { id: "c2", user_id: "u", item_id: "item2", last_synced_at: null, status: "active", last_error: "antigo" },
    ],
  }
  const pluggy = {
    getItem: (itemId: string) => {
      if (itemId === "item1") return Promise.reject(new Error("pluggy fora do ar"))
      return Promise.resolve({ id: itemId, status: "UPDATED" })
    },
    listCreditAccounts: () => Promise.resolve([{ id: "pa1", name: "CARTAO ", number: "1234", type: "CREDIT" }]),
    listTransactions: () =>
      Promise.resolve([
        { id: "t1", description: "X", amount: 10, currencyCode: "BRL", date: "2026-10-20T00:00:00.000Z", type: "DEBIT", status: "POSTED" },
      ]),
  } as unknown as PluggyClient

  const results = await syncConnections(fakeAdmin(tables), pluggy, {})

  assertEquals(results, [
    { connectionId: "c1", ok: false, error: "pluggy fora do ar" },
    { connectionId: "c2", ok: true },
  ])
  const [first, second] = tables.card_connections as Array<Record<string, unknown>>
  assertEquals(first.last_error, "pluggy fora do ar")
  assertEquals(first.last_synced_at, null)
  assert(typeof second.last_synced_at === "string")
  assertEquals(second.last_error, null)
  assertEquals((tables as Record<string, unknown[]>).card_transactions.length, 1)
})
