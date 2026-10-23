import { API_KEY_TTL_MS, PLUGGY_API } from "./cardConstants.ts"
import type { DateWindow, PluggyAccount, PluggyItem, PluggyTransaction } from "./pluggyTypes.ts"
import { connectTokenBody } from "./itemOwnership.ts"

export class PluggyError extends Error {
  constructor(message: string, readonly status: number) {
    super(message)
    this.name = "PluggyError"
  }
}

export class PluggyClient {
  private apiKey: string | null = null
  private apiKeyExpiresAt = 0

  constructor(
    private readonly clientId: string,
    private readonly clientSecret: string,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  private async authenticate(): Promise<string> {
    if (this.apiKey && Date.now() < this.apiKeyExpiresAt) return this.apiKey
    const response = await this.fetcher(`${PLUGGY_API}/auth`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ clientId: this.clientId, clientSecret: this.clientSecret }),
    })
    if (!response.ok) {
      throw new PluggyError(`Falha ao autenticar na Pluggy: ${await response.text()}`, response.status)
    }
    const payload = (await response.json()) as { apiKey: string }
    this.apiKey = payload.apiKey
    this.apiKeyExpiresAt = Date.now() + API_KEY_TTL_MS
    return this.apiKey
  }

  private async request<T>(pathWithQuery: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
    const apiKey = await this.authenticate()
    const response = await this.fetcher(`${PLUGGY_API}${pathWithQuery}`, {
      method: init.method ?? "GET",
      headers: { "X-API-KEY": apiKey, ...(init.body ? { "Content-Type": "application/json" } : {}) },
      body: init.body ? JSON.stringify(init.body) : undefined,
    })
    if (response.status === 401 || response.status === 403) {
      this.apiKey = null
      throw new PluggyError("Credenciais da Pluggy recusadas ou expiradas", response.status)
    }
    if (!response.ok) {
      throw new PluggyError(`Pluggy respondeu ${response.status}: ${await response.text()}`, response.status)
    }
    const text = await response.text()
    return (text ? JSON.parse(text) : undefined) as T
  }

  async createConnectToken(userId: string, itemId?: string): Promise<string> {
    const body = connectTokenBody(userId, itemId)
    const payload = await this.request<{ accessToken: string }>("/connect_token", { method: "POST", body })
    return payload.accessToken
  }

  getItem(itemId: string): Promise<PluggyItem> {
    return this.request<PluggyItem>(`/items/${encodeURIComponent(itemId)}`)
  }

  async deleteItem(itemId: string): Promise<void> {
    await this.request(`/items/${encodeURIComponent(itemId)}`, { method: "DELETE" })
  }

  async listAccounts(itemId: string): Promise<PluggyAccount[]> {
    const payload = await this.request<{ results: PluggyAccount[] }>(
      `/accounts?itemId=${encodeURIComponent(itemId)}`,
    )
    return payload.results
  }

  async listTransactions(accountId: string, window: DateWindow): Promise<PluggyTransaction[]> {
    const collected: PluggyTransaction[] = []
    const params = new URLSearchParams({ accountId, dateFrom: window.from, dateTo: window.to })
    let path = `/v2/transactions?${params.toString()}`
    while (path) {
      const payload = await this.request<{ results: PluggyTransaction[]; next: string | null }>(path)
      collected.push(...payload.results)
      path = payload.next ? `/v2/transactions${payload.next}` : ""
    }
    return collected
  }
}

export function createPluggyClient(): PluggyClient {
  const clientId = Deno.env.get("PLUGGY_CLIENT_ID")
  const clientSecret = Deno.env.get("PLUGGY_CLIENT_SECRET")
  if (!clientId || !clientSecret) {
    throw new PluggyError("PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET não estão configurados", 500)
  }
  return new PluggyClient(clientId, clientSecret)
}
