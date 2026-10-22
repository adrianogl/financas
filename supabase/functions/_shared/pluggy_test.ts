import { assertEquals } from "jsr:@std/assert@1"
import { PluggyClient } from "./pluggy.ts"
import type { PluggyTransaction } from "./pluggyTypes.ts"

function tx(id: string): PluggyTransaction {
  return { id, description: id, amount: 1, currencyCode: "BRL", date: "2026-10-20T00:00:00.000Z", type: "DEBIT", status: "POSTED" }
}

Deno.test("listTransactions segue o cursor next como query string de /v2/transactions", async () => {
  const paths: string[] = []
  const fetcher = ((input: string | URL | Request) => {
    const url = String(input)
    const path = url.replace("https://api.pluggy.ai", "")
    if (path === "/auth") return Promise.resolve(Response.json({ apiKey: "k" }))
    paths.push(path)
    if (paths.length === 1) return Promise.resolve(Response.json({ results: [tx("a"), tx("b")], next: "?cursor=abc" }))
    return Promise.resolve(Response.json({ results: [tx("c")], next: null }))
  }) as typeof fetch

  const client = new PluggyClient("id", "secret", fetcher)
  const result = await client.listTransactions("acc1", { from: "2026-01-01", to: "2026-10-22" })

  assertEquals(result.map((t) => t.id), ["a", "b", "c"])
  assertEquals(paths, [
    "/v2/transactions?accountId=acc1&dateFrom=2026-01-01&dateTo=2026-10-22",
    "/v2/transactions?cursor=abc",
  ])
})
