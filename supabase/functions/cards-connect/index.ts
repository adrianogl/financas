import { createClient } from "npm:@supabase/supabase-js@2.45.4"
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4"
import { UUID_PATTERN } from "../_shared/cardConstants.ts"
import { connectionStatus } from "../_shared/cardRows.ts"
import { ownsItem } from "../_shared/itemOwnership.ts"
import { createPluggyClient, PluggyError } from "../_shared/pluggy.ts"
import type { PluggyClient } from "../_shared/pluggy.ts"
import type { CardsConnectRequest } from "../_shared/pluggyTypes.ts"
import { syncConnections } from "../_shared/syncConnections.ts"

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

function parseRequest(body: unknown): CardsConnectRequest | null {
  if (typeof body !== "object" || body === null) return null
  const { action, itemId, connectionId } = body as Record<string, unknown>
  if (action === "token") {
    if (itemId === undefined || itemId === null) return { action }
    return typeof itemId === "string" && itemId.trim() !== "" ? { action, itemId } : null
  }
  if (action === "register") {
    return typeof itemId === "string" && itemId.trim() !== "" ? { action, itemId } : null
  }
  if (action === "remove") {
    return typeof connectionId === "string" && UUID_PATTERN.test(connectionId) ? { action, connectionId } : null
  }
  return null
}

async function issueToken(admin: SupabaseClient, pluggy: PluggyClient, userId: string, itemId?: string | null) {
  if (itemId) {
    const owned = await admin.from("card_connections").select("id").eq("user_id", userId).eq("item_id", itemId)
    if (owned.error) throw owned.error
    if (!owned.data || owned.data.length === 0) return json({ error: "forbidden" }, 403)
  }
  const accessToken = await pluggy.createConnectToken(userId, itemId ?? undefined)
  return json({ accessToken })
}

async function registerItem(admin: SupabaseClient, pluggy: PluggyClient, userId: string, itemId: string) {
  let item
  try {
    item = await pluggy.getItem(itemId)
  } catch (error) {
    if (error instanceof PluggyError && (error.status === 404 || error.status === 400)) {
      return json({ error: "forbidden" }, 403)
    }
    throw error
  }
  if (!ownsItem(item, userId)) return json({ error: "forbidden" }, 403)

  const upserted = await admin
    .from("card_connections")
    .upsert({ user_id: userId, item_id: itemId, status: connectionStatus(item) }, { onConflict: "item_id" })
    .select("id")
  if (upserted.error) throw upserted.error
  const connectionId = upserted.data?.[0]?.id as string | undefined
  if (!connectionId) throw new Error("Falha ao registrar a conexão")

  const results = await syncConnections(admin, pluggy, { userId, connectionIds: [connectionId] })
  return json({ connectionId, results })
}

async function removeConnection(admin: SupabaseClient, pluggy: PluggyClient, userId: string, connectionId: string) {
  const found = await admin
    .from("card_connections")
    .select("id, item_id")
    .eq("id", connectionId)
    .eq("user_id", userId)
  if (found.error) throw found.error
  const connection = found.data?.[0] as { id: string; item_id: string } | undefined
  if (!connection) return json({ error: "forbidden" }, 403)

  try {
    await pluggy.deleteItem(connection.item_id)
  } catch (error) {
    if (!(error instanceof PluggyError && error.status === 404)) throw error
  }
  const deleted = await admin.from("card_connections").delete().eq("id", connectionId).eq("user_id", userId)
  if (deleted.error) throw deleted.error
  return json({ ok: true })
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405)

  const url = Deno.env.get("SUPABASE_URL")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!url || !serviceKey) return json({ error: "misconfigured" }, 500)
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "")
  if (!token) return json({ error: "unauthorized" }, 401)
  const { data, error } = await admin.auth.getUser(token)
  if (error || !data.user) return json({ error: "unauthorized" }, 401)
  const userId = data.user.id

  const parsed = parseRequest(await request.json().catch(() => null))
  if (!parsed) return json({ error: "bad_request" }, 400)

  try {
    const pluggy = createPluggyClient()
    switch (parsed.action) {
      case "token":
        return await issueToken(admin, pluggy, userId, parsed.itemId)
      case "register":
        return await registerItem(admin, pluggy, userId, parsed.itemId)
      case "remove":
        return await removeConnection(admin, pluggy, userId, parsed.connectionId)
    }
  } catch (caught) {
    return json({ error: caught instanceof Error ? caught.message : "connect_failed" }, 500)
  }
})
