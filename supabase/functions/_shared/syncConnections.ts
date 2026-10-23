import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4"
import { UPSERT_CHUNK_SIZE } from "./cardConstants.ts"
import { accountRow, connectionStatus, syncWindow, transactionRow } from "./cardRows.ts"
import type { PluggyClient } from "./pluggy.ts"
import type { ConnectionRecord, ConnectionSyncResult, DateWindow, SyncFilter } from "./pluggyTypes.ts"

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === "object" && error !== null && "message" in error) return String((error as { message: unknown }).message)
  return String(error)
}

function chunks<T>(items: T[], size: number): T[][] {
  const result: T[][] = []
  for (let i = 0; i < items.length; i += size) result.push(items.slice(i, i + size))
  return result
}

async function removeStalePending(
  admin: SupabaseClient,
  cardAccountId: string,
  window: DateWindow,
  returnedIds: Set<string>,
): Promise<void> {
  const pending = await admin
    .from("card_transactions")
    .select("id")
    .eq("card_account_id", cardAccountId)
    .eq("is_pending", true)
    .gte("date", window.from)
    .lte("date", window.to)
  if (pending.error) throw pending.error
  const staleIds = (pending.data ?? [])
    .map((row: { id: string }) => row.id)
    .filter((id: string) => !returnedIds.has(id))
  for (const chunk of chunks(staleIds, UPSERT_CHUNK_SIZE)) {
    const result = await admin.from("card_transactions").delete().in("id", chunk)
    if (result.error) throw result.error
  }
}

async function syncAccountTransactions(
  admin: SupabaseClient,
  pluggy: PluggyClient,
  connection: ConnectionRecord,
  pluggyAccountId: string,
  cardAccountId: string,
  lastSyncedAt: string | null,
  today: string,
): Promise<void> {
  const window = syncWindow(lastSyncedAt, today)
  const transactions = await pluggy.listTransactions(pluggyAccountId, window)
  const txRows = transactions.map((tx) => ({
    ...transactionRow(tx, cardAccountId),
    user_id: connection.user_id,
  }))
  for (const chunk of chunks(txRows, UPSERT_CHUNK_SIZE)) {
    const result = await admin.from("card_transactions").upsert(chunk, { onConflict: "id" })
    if (result.error) throw result.error
  }
  await removeStalePending(admin, cardAccountId, window, new Set(txRows.map((row) => row.id)))
}

async function removeUntouchedAccount(admin: SupabaseClient, cardAccountId: string, defaultNickname: string): Promise<void> {
  const recurrences = await admin.from("card_recurrences").select("id").eq("card_account_id", cardAccountId)
  if (recurrences.error) {
    console.error("falha ao verificar recorrências antes de limpar a conta nova", recurrences.error)
    return
  }
  if ((recurrences.data ?? []).length > 0) return
  const removal = await admin.from("card_accounts").delete().eq("id", cardAccountId).eq("nickname", defaultNickname)
  if (removal.error) console.error("falha ao limpar a conta nova após erro na primeira sincronização", removal.error)
}

async function syncConnection(
  admin: SupabaseClient,
  pluggy: PluggyClient,
  connection: ConnectionRecord,
  today: string,
): Promise<void> {
  const item = await pluggy.getItem(connection.item_id)
  const status = connectionStatus(item)
  await admin.from("card_connections").update({ status }).eq("id", connection.id)

  const existing = await admin
    .from("card_accounts")
    .select("pluggy_account_id, nickname")
    .eq("connection_id", connection.id)
  if (existing.error) throw existing.error
  const nicknames = new Map<string, string>(
    (existing.data ?? []).map((row: { pluggy_account_id: string; nickname: string }) => [row.pluggy_account_id, row.nickname]),
  )

  const accounts = await pluggy.listCreditAccounts(connection.item_id)
  for (const account of accounts) {
    const isNew = !nicknames.has(account.id)
    const upserted = await admin
      .from("card_accounts")
      .upsert(
        [{ ...accountRow(account, connection.id, nicknames.get(account.id)), user_id: connection.user_id }],
        { onConflict: "pluggy_account_id" },
      )
      .select("id, pluggy_account_id")
    if (upserted.error) throw upserted.error
    const cardAccountId = (upserted.data ?? [])[0]?.id as string | undefined
    if (!cardAccountId) continue

    try {
      await syncAccountTransactions(admin, pluggy, connection, account.id, cardAccountId, isNew ? null : connection.last_synced_at, today)
    } catch (error) {
      if (isNew) await removeUntouchedAccount(admin, cardAccountId, accountRow(account, connection.id).nickname)
      throw error
    }
  }

  if (status === "active") {
    const done = await admin
      .from("card_connections")
      .update(accounts.length > 0 ? { last_synced_at: new Date().toISOString(), last_error: null } : { last_error: null })
      .eq("id", connection.id)
    if (done.error) throw done.error
    return
  }

  throw new Error(`Item da Pluggy com status ${item.status}`)
}

export async function syncConnections(
  admin: SupabaseClient,
  pluggy: PluggyClient,
  filter: SyncFilter,
): Promise<ConnectionSyncResult[]> {
  let query = admin.from("card_connections").select("id, user_id, item_id, last_synced_at")
  if (filter.userId) query = query.eq("user_id", filter.userId)
  if (filter.connectionIds) query = query.in("id", filter.connectionIds)
  const { data, error } = await query
  if (error) throw error

  const today = new Date().toISOString().slice(0, 10)
  const results: ConnectionSyncResult[] = []
  for (const connection of (data ?? []) as ConnectionRecord[]) {
    try {
      await syncConnection(admin, pluggy, connection, today)
      results.push({ connectionId: connection.id, ok: true })
    } catch (error) {
      const message = errorMessage(error)
      await admin.from("card_connections").update({ last_error: message }).eq("id", connection.id)
      results.push({ connectionId: connection.id, ok: false, error: message })
    }
  }
  return results
}
