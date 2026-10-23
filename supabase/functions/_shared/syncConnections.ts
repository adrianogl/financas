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
  if (accounts.length > 0) {
    const rows = accounts.map((account) => ({
      ...accountRow(account, connection.id, nicknames.get(account.id)),
      user_id: connection.user_id,
    }))
    const upserted = await admin
      .from("card_accounts")
      .upsert(rows, { onConflict: "pluggy_account_id" })
      .select("id, pluggy_account_id")
    if (upserted.error) throw upserted.error

    const cardIds = new Map<string, string>(
      (upserted.data ?? []).map((row: { id: string; pluggy_account_id: string }) => [row.pluggy_account_id, row.id]),
    )
    for (const account of accounts) {
      const window = syncWindow(nicknames.has(account.id) ? connection.last_synced_at : null, today)
      const cardAccountId = cardIds.get(account.id)
      if (!cardAccountId) continue
      const transactions = await pluggy.listTransactions(account.id, window)
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
  }

  const done = await admin
    .from("card_connections")
    .update(accounts.length > 0 ? { last_synced_at: new Date().toISOString(), last_error: null } : { last_error: null })
    .eq("id", connection.id)
  if (done.error) throw done.error

  if (status !== "active") {
    throw new Error(`Item da Pluggy com status ${item.status}`)
  }
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
