import { assert, assertEquals } from "jsr:@std/assert@1"
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4"
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
    listAccounts: () => Promise.resolve([{ id: "pa1", name: "CARTAO ", number: "1234", type: "CREDIT" }]),
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
    listAccounts: () => Promise.resolve([{ id: "pa1", name: "CARTAO", number: "1234", type: "CREDIT" }]),
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
    listAccounts: () =>
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

Deno.test("item não ativo não avança last_synced_at, grava erro uma vez e salva o que a Pluggy já tem", async () => {
  const previous = "2026-09-01T10:00:00.000Z"
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: previous, status: "active", last_error: null },
    ],
    card_accounts: [{ id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "n" }],
  }
  const pluggy = {
    getItem: () => Promise.resolve({ id: "item1", status: "OUTDATED" }),
    listAccounts: () => Promise.resolve([{ id: "pa1", name: "CARTAO", number: "1234", type: "CREDIT" }]),
    listTransactions: () =>
      Promise.resolve([
        { id: "t1", description: "X", amount: 10, currencyCode: "BRL", date: "2026-10-20T00:00:00.000Z", type: "DEBIT", status: "POSTED" },
      ]),
  } as unknown as PluggyClient

  const results = await syncConnections(fakeAdmin(tables), pluggy, {})

  assertEquals(results, [{ connectionId: "c1", ok: false, error: "Item da Pluggy com status OUTDATED" }])
  assertEquals(tables.card_connections[0].last_synced_at, previous)
  assertEquals(tables.card_connections[0].status, "error")
  assertEquals(tables.card_connections[0].last_error, "Item da Pluggy com status OUTDATED")
  assertEquals(tables.card_transactions.length, 1)
})

Deno.test("depois de reconectar, a janela parte do last_synced_at antigo e só então avança", async () => {
  const previous = "2026-09-01T10:00:00.000Z"
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: previous, status: "active", last_error: null },
    ],
    card_accounts: [{ id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "n" }],
  }
  await syncConnections(fakeAdmin(tables), recordingPluggy("OUTDATED", ["pa1"], {}), {})
  const windows: Record<string, Window> = {}
  const today = new Date().toISOString().slice(0, 10)

  const results = await syncConnections(fakeAdmin(tables), recordingPluggy("UPDATED", ["pa1"], windows), {})

  assertEquals(results, [{ connectionId: "c1", ok: true }])
  assertEquals(windows.pa1, syncWindow(previous, today))
  assert(String(tables.card_connections[0].last_synced_at) > previous)
  assertEquals(tables.card_connections[0].last_error, null)
})

function failingAfterTransactionUpsert(admin: SupabaseClient): SupabaseClient {
  return {
    from: (table: string) => {
      const query = admin.from(table)
      if (table !== "card_transactions") return query
      return {
        upsert: (...args: Parameters<typeof query.upsert>) => query.upsert(...args),
        select: () => {
          throw new Error("falha ao ler pendentes")
        },
      }
    },
  } as unknown as SupabaseClient
}

Deno.test("conta nova cuja primeira sincronização falha recebe a janela de 12 meses na próxima execução", async () => {
  const lastSyncedAt = new Date().toISOString()
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: lastSyncedAt, status: "active", last_error: null },
    ],
    card_accounts: [{ id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "n" }],
  }
  const failing = {
    getItem: () => Promise.resolve({ id: "item1", status: "UPDATED" }),
    listAccounts: () =>
      Promise.resolve(["pa1", "pa2", "pa3"].map((id) => ({ id, name: "CARTAO", number: "1234", type: "CREDIT" }))),
    listTransactions: (accountId: string) =>
      Promise.resolve(
        accountId === "pa2"
          ? [{ id: "t-pa2", description: "X", amount: 10, currencyCode: "BRL", date: "2026-10-20T00:00:00.000Z", type: "DEBIT", status: "POSTED" }]
          : [],
      ),
  } as unknown as PluggyClient
  const admin = failingAfterTransactionUpsert(fakeAdmin(tables))

  const first = await syncConnections(admin, failing, {})
  assertEquals(first, [{ connectionId: "c1", ok: false, error: "falha ao ler pendentes" }])
  assertEquals(tables.card_accounts.map((row) => row.pluggy_account_id), ["pa1"])
  assertEquals(tables.card_transactions ?? [], [])

  const windows: Record<string, Window> = {}
  await syncConnections(fakeAdmin(tables), recordingPluggy("UPDATED", ["pa1", "pa2", "pa3"], windows), {})

  const today = new Date().toISOString().slice(0, 10)
  assertEquals(windows.pa1, syncWindow(lastSyncedAt, today))
  assertEquals(windows.pa2, syncWindow(null, today))
  assertEquals(windows.pa3, syncWindow(null, today))
})

for (const scenario of ["apelido alterado", "recorrência confirmada"]) {
  Deno.test(`limpeza não apaga conta nova com ${scenario} durante a falha`, async () => {
    const lastSyncedAt = new Date().toISOString()
    const tables: Record<string, Array<Record<string, unknown>>> = {
      card_connections: [
        { id: "c1", user_id: "u", item_id: "item1", last_synced_at: lastSyncedAt, status: "active", last_error: null },
      ],
    }
    const pluggy = {
      getItem: () => Promise.resolve({ id: "item1", status: "UPDATED" }),
      listAccounts: () => Promise.resolve([{ id: "pa2", name: "CARTAO", number: "1234", type: "CREDIT" }]),
      listTransactions: () => {
        const account = tables.card_accounts[0]
        if (scenario === "apelido alterado") account.nickname = "Meu cartão"
        else tables.card_recurrences = [{ id: "r1", card_account_id: account.id, merchant_key: "m", status: "confirmed" }]
        return Promise.reject(new Error("falha ao buscar"))
      },
    } as unknown as PluggyClient

    await syncConnections(fakeAdmin(tables), pluggy, {})
    assertEquals(tables.card_accounts.length, 1)

    const windows: Record<string, Window> = {}
    await syncConnections(fakeAdmin(tables), recordingPluggy("UPDATED", ["pa2"], windows), {})
    const today = new Date().toISOString().slice(0, 10)
    assertEquals(windows.pa2, syncWindow(lastSyncedAt, today))
  })
}

function bankingPluggy(accounts: unknown[]): PluggyClient {
  return {
    getItem: () => Promise.resolve({ id: "item1", status: "UPDATED" }),
    listAccounts: () => Promise.resolve(accounts),
    listTransactions: () => Promise.resolve([]),
  } as unknown as PluggyClient
}

const c6Accounts = [
  { id: "b1", name: "C6 BANK", number: "0001", type: "BANK", bankData: { transferNumber: "336/0001/00040367-9" } },
  {
    id: "pa1",
    name: "BANDEIRADO",
    number: "4526",
    type: "CREDIT",
    creditData: { brand: "MASTERCARD", level: "BLACK" },
  },
]

Deno.test("grava institution_name na conexão e brand_label e apelido do banco na conta, só para CREDIT", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
  }

  await syncConnections(fakeAdmin(tables), bankingPluggy(c6Accounts), {})

  assertEquals(tables.card_connections[0].institution_name, "C6")
  assertEquals(tables.card_accounts.length, 1)
  assertEquals(tables.card_accounts[0].nickname, "C6")
  assertEquals(tables.card_accounts[0].brand_label, "Mastercard Black")
})

Deno.test("sync atualiza o apelido padrão antigo e preserva o apelido alterado pelo usuário", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
    card_accounts: [
      { id: "acc1", connection_id: "c1", pluggy_account_id: "pa1", nickname: "BANDEIRADO ····4526" },
      { id: "acc2", connection_id: "c1", pluggy_account_id: "pa2", nickname: "Cartão do trabalho" },
    ],
  }
  const second = { id: "pa2", name: "OUTRO", number: "9999", type: "CREDIT" }

  await syncConnections(fakeAdmin(tables), bankingPluggy([...c6Accounts, second]), {})

  assertEquals(tables.card_accounts.map((row) => row.nickname), ["C6", "Cartão do trabalho"])
})

Deno.test("limpeza remove conta nova ainda com o apelido padrão novo quando a primeira sincronização falha", async () => {
  const tables: Record<string, Array<Record<string, unknown>>> = {
    card_connections: [
      { id: "c1", user_id: "u", item_id: "item1", last_synced_at: null, status: "active", last_error: null },
    ],
  }
  const pluggy = {
    getItem: () => Promise.resolve({ id: "item1", status: "UPDATED" }),
    listAccounts: () => Promise.resolve(c6Accounts),
    listTransactions: () => Promise.reject(new Error("falha ao buscar")),
  } as unknown as PluggyClient

  await syncConnections(fakeAdmin(tables), pluggy, {})

  assertEquals(tables.card_accounts.length, 0)
})
