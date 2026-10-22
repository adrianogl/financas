import { createClient } from "npm:@supabase/supabase-js@2.45.4"
import { CRON_SECRET_HEADER } from "../_shared/cardConstants.ts"
import { createPluggyClient } from "../_shared/pluggy.ts"
import { syncConnections } from "../_shared/syncConnections.ts"
import type { SyncFilter } from "../_shared/pluggyTypes.ts"

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

function timingSafeEqual(a: string, b: string): boolean {
  const encoder = new TextEncoder()
  const left = encoder.encode(a)
  const right = encoder.encode(b)
  if (left.length !== right.length) return false
  let diff = 0
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i]
  return diff === 0
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405)

  const url = Deno.env.get("SUPABASE_URL")
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!url || !serviceKey) return json({ error: "misconfigured" }, 500)
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

  const cronSecret = Deno.env.get("CARDS_CRON_SECRET")
  const providedSecret = request.headers.get(CRON_SECRET_HEADER)
  let filter: SyncFilter

  if (providedSecret) {
    if (!cronSecret || !timingSafeEqual(providedSecret, cronSecret)) return json({ error: "unauthorized" }, 401)
    filter = {}
  } else {
    const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "")
    if (!token) return json({ error: "unauthorized" }, 401)
    const { data, error } = await admin.auth.getUser(token)
    if (error || !data.user) return json({ error: "unauthorized" }, 401)
    filter = { userId: data.user.id }
    const body = await request.json().catch(() => ({}))
    if (typeof body?.connectionId === "string") filter.connectionIds = [body.connectionId]
  }

  try {
    const results = await syncConnections(admin, createPluggyClient(), filter)
    return json({ results })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "sync_failed" }, 500)
  }
})
