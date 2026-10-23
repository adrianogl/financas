import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4"

type Row = Record<string, unknown>
type Tables = Record<string, Row[]>

class FakeQuery {
  private filters: Array<(row: Row) => boolean> = []
  private action: "select" | "update" | "upsert" | "delete" = "select"
  private patch: Row = {}
  private upserted: Row[] = []
  private conflictKey = "id"

  constructor(private readonly tables: Tables, private readonly table: string) {}

  select(_columns?: string) {
    return this
  }

  eq(column: string, value: unknown) {
    this.filters.push((row) => row[column] === value)
    return this
  }

  in(column: string, values: unknown[]) {
    this.filters.push((row) => values.includes(row[column]))
    return this
  }

  gte(column: string, value: string) {
    this.filters.push((row) => String(row[column]) >= value)
    return this
  }

  lte(column: string, value: string) {
    this.filters.push((row) => String(row[column]) <= value)
    return this
  }

  delete() {
    this.action = "delete"
    return this
  }

  update(patch: Row) {
    this.action = "update"
    this.patch = patch
    return this
  }

  upsert(rows: Row | Row[], options: { onConflict: string }) {
    this.action = "upsert"
    this.conflictKey = options.onConflict
    const list = Array.isArray(rows) ? rows : [rows]
    const store = (this.tables[this.table] ??= [])
    for (const row of list) {
      const existing = store.find((r) => r[this.conflictKey] === row[this.conflictKey])
      if (existing) {
        Object.assign(existing, row)
        this.upserted.push(existing)
      } else {
        const created = { id: crypto.randomUUID(), ...row }
        store.push(created)
        this.upserted.push(created)
      }
    }
    return this
  }

  then<T>(resolve: (value: { data: Row[] | null; error: null }) => T) {
    const store = (this.tables[this.table] ??= [])
    const matches = store.filter((row) => this.filters.every((f) => f(row)))
    if (this.action === "update") {
      for (const row of matches) Object.assign(row, this.patch)
      return Promise.resolve(resolve({ data: null, error: null }))
    }
    if (this.action === "delete") {
      this.tables[this.table] = store.filter((row) => !matches.includes(row))
      if (this.table === "card_accounts") {
        const removed = new Set(matches.map((row) => row.id))
        for (const child of ["card_transactions", "card_recurrences"]) {
          if (this.tables[child]) this.tables[child] = this.tables[child].filter((row) => !removed.has(row.card_account_id))
        }
      }
      return Promise.resolve(resolve({ data: null, error: null }))
    }
    if (this.action === "upsert") return Promise.resolve(resolve({ data: this.upserted, error: null }))
    return Promise.resolve(resolve({ data: matches, error: null }))
  }
}

export function fakeAdmin(tables: Tables): SupabaseClient {
  return { from: (table: string) => new FakeQuery(tables, table) } as unknown as SupabaseClient
}
