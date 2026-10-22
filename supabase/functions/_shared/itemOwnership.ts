import type { ConnectTokenBody, PluggyItem } from "./pluggyTypes.ts"

export function ownsItem(item: PluggyItem, userId: string): boolean {
  return typeof item.clientUserId === "string" && item.clientUserId === userId
}

export function connectTokenBody(userId: string, itemId?: string): ConnectTokenBody {
  return { ...(itemId ? { itemId } : {}), options: { clientUserId: userId } }
}
