import { assert, assertEquals } from "jsr:@std/assert@1"
import { fakeAdmin } from "./fakeAdmin.ts"
import type { PluggyClient } from "./pluggy.ts"
import { syncWindow } from "./cardRows.ts"
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

Deno.test("remove pendentes da janela que a Pluggy não devolveu mais, mantendo devolvidas e lançadas", async () => {
  const today = new Date().toISOString().slice(0, 10)
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
    card_accounts: [{ id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "n" }],
    card_transactions: [
      { id: "pend-gone", card_account_id: "acc1", date: today, is_pending: true },
      { id: "pend-kept", card_account_id: "acc1", date: today, is_pending: true },
      { id: "posted-gone", card_account_id: "acc1", date: today, is_pending: false },
      { id: "pend-old", card_account_id: "acc1", date: "2000-01-01", is_pending: true },
      { id: "pend-other-account", card_account_id: "acc2", date: today, is_pending: true },
    ],
  }
  const pluggy = {
    getItem: () => Promise.resolve({ id: "item1", status: "UPDATED" }),
    listCreditAccounts: () => Promise.resolve([{ id: "pa1", name: "CARTAO", number: "1234", type: "CREDIT" }]),
    listTransactions: () =>
      Promise.resolve([
        { id: "pend-kept", description: "X", amount: 10, currencyCode: "BRL", date: `${today}T00:00:00.000Z`, type: "DEBIT", status: "PENDING" },
      ]),
  } as unknown as PluggyClient

  const results = await syncConnections(fakeAdmin(tables), pluggy, {})

  assertEquals(results, [{ connectionId: "c1", ok: true }])
  assertEquals(
    tables.card_transactions.map((row) => row.id).sort(),
    ["pend-kept", "pend-old", "pend-other-account", "posted-gone"],
  )
})

type Window = { from: string; to: string }

function recordingPluggy(status: string, accountIds: string[], windows: Record<string, Window>): PluggyClient {
  return {
    getItem: () => Promise.resolve({ id: "item1", status }),
    listCreditAccounts: () =>
      Promise.resolve(accountIds.map((id) => ({ id, name: "CARTAO", number: "1234", type: "CREDIT" }))),
    listTransactions: (accountId: string, window: Window) => {
      windows[accountId] = window
      return Promise.resolve([])
    },
  } as unknown as PluggyClient
}

Deno.test("conta nova numa conexão já sincronizada recebe a janela de 12 meses", async () => {
  const lastSyncedAt = new Date().toISOString()
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: lastSyncedAt, status: "active", last_error: null },
    ],
    card_accounts: [{ id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "n" }],
  }
  const windows: Record<string, Window> = {}

  await syncConnections(fakeAdmin(tables), recordingPluggy("UPDATED", ["pa1", "pa2"], windows), {})

  const today = new Date().toISOString().slice(0, 10)
  assertEquals(windows.pa1, syncWindow(lastSyncedAt, today))
  assertEquals(windows.pa2, syncWindow(null, today))
})

Deno.test("item sem contas de crédito não avança last_synced_at", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: "antigo" },
    ],
  }

  const results = await syncConnections(fakeAdmin(tables), recordingPluggy("UPDATING", [], {}), {})

  assertEquals(results, [{ connectionId: "c1", ok: true }])
  assertEquals(tables.card_connections[0].last_synced_at, null)
  assertEquals(tables.card_connections[0].last_error, null)
})

Deno.test("status OUTDATED é gravado e as contas e transações já coletadas continuam sendo lidas", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
  }
  const windows: Record<string, Window> = {}

  const results = await syncConnections(fakeAdmin(tables), recordingPluggy("OUTDATED", ["pa1"], windows), {})

  assertEquals(results, [{ connectionId: "c1", ok: false, error: "Item da Pluggy com status OUTDATED" }])
  assertEquals(tables.card_connections[0].status, "error")
  assertEquals(tables.card_connections[0].last_error, "Item da Pluggy com status OUTDATED")
  assertEquals(Object.keys(windows), ["pa1"])
  assertEquals(tables.card_accounts.length, 1)
})

Deno.test("LOGIN_ERROR marca needs_reconnect e ainda lê o que existe", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
  }
  const windows: Record<string, Window> = {}

  await syncConnections(fakeAdmin(tables), recordingPluggy("LOGIN_ERROR", ["pa1"], windows), {})

  assertEquals(tables.card_connections[0].status, "needs_reconnect")
  assertEquals(Object.keys(windows), ["pa1"])
})
